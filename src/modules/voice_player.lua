--------------------------------------------------------------------------------------------------------------------------------
-- Modulo voci (caricato da main.lua): riproduce un .wav per ogni bolla di dialogo.
--
-- Struttura cartelle (in scripts/):
--   voice_lines/
--     Komor/      0123456789abcdef.wav
--     ...
--     variables.tsv (generato da extractScript.py: modelli delle bolle con variabili)
--     misses.tsv  (scritto solo in debug: bolle senza audio)
--
-- Il nome del file (senza .wav) e' l'hash della bolla (colonna "hash" del copione); la sottocartella e' libera.
-- Nessun indice: i file vengono trovati cercando in tutte le sottocartelle all'avvio dello script.
--------------------------------------------------------------------------------------------------------------------------------

luanet.load_assembly("System")
local SoundPlayer  = luanet.import_type("System.Media.SoundPlayer")
local Directory    = luanet.import_type("System.IO.Directory")
local IOPath       = luanet.import_type("System.IO.Path")
local SearchOption = luanet.import_type("System.IO.SearchOption")

-- Config ----------------------------------------------------------------------------------------------------------------------

local DEBUG         = false   -- impostato da main.lua
local DEBUG_HEADERS = false   -- logga gli header di dialogo non riconosciuti (utile per la prof. Aralia)

-- Frame per carattere durante la stampa del testo: va tarato sulla velocita' testo scelta nel gioco.
-- Una pressione di A/B mentre il testo si sta ancora scrivendo completa solo il testo, non cambia bolla.
local FRAMES_PER_CHAR = 1

-- Lunghezza massima (in caratteri) del testo che una variabile puo' diventare (nome Pokemon, numero, strumento...)
local MAX_VAR_LEN = 20

-- Comandi testo Gen 5 (F000 <cmd> <nArgs> <args...>)
local CMD_START  = 0xF000
local CMD_PAGE   = 0xBE01     -- attende tasto + pulisce la bolla  -> nuovo file audio
local CMD_SCROLL = 0xBE00     -- attende tasto + scorre la riga    -> stesso file audio, ma serve una pressione
local NEWLINE    = 0xFFFE

-- Memoria
local DIALOG_ADDR, DIALOG_WORDS = 0x25AF20, 2048  -- dialoghi normali (0 quando il dialogo e' chiuso)
-- Buffer extra (es. introduzione della Prof.ssa Aralia): non vengono azzerati alla chiusura,
-- quindi un dialogo nuovo viene riconosciuto solo quando il loro contenuto cambia.
local EXTRA_DIALOG_ADDRS = {
	0x2D6C50, 0x2D7908,   -- introduzione Prof.ssa Aralia
}
-- Puntatori a buffer extra: per l'interfono ogni battuta ha un buffer nuovo in un punto diverso,
-- ma a questo indirizzo c'e' sempre il puntatore (0x02xxxxxx) alla struttura della battuta attuale.
-- Il marcatore D2EC B6F8 sta 4 byte dopo l'inizio della struttura.
local EXTRA_DIALOG_PTRS = {
	0x2696DC,             -- interfono
}
local PTR_TO_MAGIC = 4
local DIALOG_HDR1, DIALOG_HDR2  = 0xD2EC, 0xB6F8
local NAME_ADDRS = { 0x24F82C, 0x24F6C8 }    -- nome giocatore: gioco / intro
local NAME_PLACEHOLDER = 0xE001              -- uguale a PLACEHOLDER di extract_script.py
local CMD_PLAYER_NAME  = 0x0100              -- F000 0100 n 0000 = nome del giocatore (testo non ancora espanso)

-- Percorsi: impostati in M.init a partire dalla cartella scripts/ passata da main.lua
local VOICES, MISSES_FILE, VAR_FILE

-- Stato -----------------------------------------------------------------------------------------------------------------------

local voicePlayer  = nil
local currentHash  = nil
local currentSrc   = nil     -- "main" o indirizzo del buffer extra da cui viene il dialogo corrente
local extraSeen    = {}      -- buffer extra -> hash dell'ultimo contenuto gia' visto
local mainSeen     = nil     -- hash dell'ultimo contenuto visto nel buffer dei dialoghi normali
local pages        = {}      -- { hash, text, segs = {nChars, ...} }
local pageIdx      = 0
local segIdx       = 1       -- segmento della bolla corrente (separati da CMD_SCROLL)
local segStart     = 0       -- frame di inizio stampa del segmento
local segDone      = false   -- testo del segmento gia' completato da una pressione
local prevPressed  = false
local loggedMisses = {}
local seenHeaders  = {}

--------------------------------------------------------------------------------------------------------------------------------
-- Caricamento file audio

local hashToPath = {}   -- hash pagina -> percorso assoluto .wav

local function add_voice(hash, path)
	hash = hash:lower()
	if DEBUG and hashToPath[hash] and hashToPath[hash] ~= path then
		console.log("ATTENZIONE: hash duplicato " .. hash .. "\n  " .. hashToPath[hash] .. "\n  " .. path)
	end
	hashToPath[hash] = path
end

local function load_voices()
	local count = 0

	-- Scansione ricorsiva: voice_lines/<personaggio>/<hash>.wav
	if Directory.Exists(VOICES) then
		local files = Directory.GetFiles(VOICES, "*.wav", SearchOption.AllDirectories)
		for i = 0, files.Length - 1 do
			local full = files[i]
			local name = IOPath.GetFileNameWithoutExtension(full)
			if #name == 16 and name:match("^%x+$") then
				add_voice(name, IOPath.GetFullPath(full))
				count = count + 1
			end
		end
	else
		console.log("ERRORE: cartella non trovata " .. VOICES)
	end

	console.log("Voci caricate: " .. count .. " file da " .. VOICES)
end

--------------------------------------------------------------------------------------------------------------------------------
-- Bolle con variabili
-- In RAM le variabili sono gia' sostituite dal testo vero (es. "Snivy"), quindi l'hash non coincide con quello della ROM.
-- variables.tsv contiene, per ogni bolla con variabili, i pezzi fissi: se la bolla in RAM e' fatta da quei pezzi
-- con del testo qualsiasi in mezzo, si usa l'hash del modello (= nome del .wav).

local varTemplates = {}   -- { hash, segs = { {word, ...}, ... } }

local function load_templates()
	local f = io.open(VAR_FILE, "r")
	if not f then
		console.log("Nessun " .. VAR_FILE .. ": le bolle con variabili non avranno audio")
		return
	end
	local total = 0
	for line in f:lines() do
		line = line:gsub("\r$", "")
		local fields = {}
		for field in (line .. "\t"):gmatch("([^\t]*)\t") do
			fields[#fields + 1] = field
		end
		if #fields >= 3 then
			total = total + 1
			local hash = fields[1]:lower()
			if hashToPath[hash] then   -- solo i modelli che hanno gia' un audio registrato
				local t = { hash = hash, segs = {} }
				for k = 2, #fields do
					local seg = {}
					for hex in fields[k]:gmatch("%x%x%x%x") do
						seg[#seg + 1] = tonumber(hex, 16)
					end
					t.segs[#t.segs + 1] = seg
				end
				varTemplates[#varTemplates + 1] = t
			end
		end
	end
	f:close()
	console.log("Modelli con variabili: " .. #varTemplates .. " con audio (su " .. total .. ")")
end

local function seg_at(words, pos, seg)
	for k = 1, #seg do
		if words[pos + k - 1] ~= seg[k] then
			return false
		end
	end
	return true
end

-- words[pos..] corrisponde a segs[si], poi variabile, segs[si+1], ... fino alla fine esatta della bolla?
local function match_from(words, segs, si, pos)
	local seg = segs[si]
	if not seg_at(words, pos, seg) then
		return false
	end
	pos = pos + #seg
	if si == #segs then
		return pos == #words + 1
	end
	for gap = 1, MAX_VAR_LEN do
		if pos + gap > #words + 1 then
			break
		end
		if match_from(words, segs, si + 1, pos + gap) then
			return true
		end
	end
	return false
end


--------------------------------------------------------------------------------------------------------------------------------
-- Lettura memoria

local function read_dialog(addr)
	addr = addr or DIALOG_ADDR
	local h1 = memory.read_u16_le(addr)
	local h2 = memory.read_u16_le(addr + 2)
	if h1 == 0 and h2 == 0 then
		return "CLOSED"
	end
	if h1 ~= DIALOG_HDR1 or h2 ~= DIALOG_HDR2 then
		if DEBUG_HEADERS and addr == DIALOG_ADDR then
			local key = string.format("%04X %04X", h1, h2)
			if not seenHeaders[key] then
				seenHeaders[key] = true
				console.log("Header sconosciuto @" .. string.format("%06X", DIALOG_ADDR) .. ": " .. key)
			end
		end
		return nil
	end
	if memory.read_u16_le(addr + 4) == 0xFFFF then
		return nil
	end

	local words = {}
	for i = 2, DIALOG_WORDS - 1 do
		local w = memory.read_u16_le(addr + i * 2)
		if w == 0xFFFF then
			break
		end
		words[#words + 1] = w
	end
	return words
end

local function read_name_at(addr)
	local name = {}
	for i = 0, 9 do
		local w = memory.read_u16_le(addr + i * 2)
		if w == 0xFFFF or w == 0 then
			break
		end
		name[#name + 1] = w
	end
	return name
end

local function read_player_names()
	local names, seen = {}, {}
	for _, addr in ipairs(NAME_ADDRS) do
		local n = read_name_at(addr)
		local key = table.concat(n, ",")
		if #n >= 1 and not seen[key] then
			seen[key] = true
			names[#names + 1] = n
		end
	end
	return names
end

-- Posizioni in cui compare il nome del giocatore nella bolla
local function find_occurrences(words, name)
	local occ, i = {}, 1
	while i <= #words - #name + 1 do
		local ok = true
		for j = 1, #name do
			if words[i + j - 1] ~= name[j] then ok = false; break end
		end
		if ok then
			occ[#occ + 1] = i
			i = i + #name
		else
			i = i + 1
		end
	end
	return occ
end

-- Sostituisce con il segnaposto solo le occorrenze indicate dai bit di mask
local function replace_at(words, name, occ, mask)
	local out, i, k = {}, 1, 1
	while i <= #words do
		if occ[k] == i then
			if (mask >> (k - 1)) & 1 == 1 then
				out[#out + 1] = NAME_PLACEHOLDER
			else
				for j = 0, #name - 1 do out[#out + 1] = words[i + j] end
			end
			i = i + #name
			k = k + 1
		else
			out[#out + 1] = words[i]
			i = i + 1
		end
	end
	return out
end

-- Testo non ancora espanso: il comando "nome giocatore" diventa il segnaposto (come in extract_script.py)
local function normalize_player_cmd(words)
	local out, i = {}, 1
	while i <= #words do
		local n = words[i + 2] or 0
		if words[i] == CMD_START and words[i + 1] == CMD_PLAYER_NAME and n >= 1 and words[i + 3] == 0 then
			out[#out + 1] = NAME_PLACEHOLDER
			i = i + 3 + n
		else
			out[#out + 1] = words[i]
			i = i + 1
		end
	end
	return out
end

--------------------------------------------------------------------------------------------------------------------------------
-- Hash / decodifica / pagine  (hash e split IDENTICI all'originale: devono combaciare con extract_script.py)

local function hash_words(words)
	local h = 0xcbf29ce484222325
	for _, w in ipairs(words) do
		h = (h ~ (w & 0xFF)) * 0x100000001b3
		h = (h ~ (w >> 8)) * 0x100000001b3
	end
	return string.format("%016x", h)
end

local function decode(words)
	local s = {}
	for _, w in ipairs(words) do
		if w == NAME_PLACEHOLDER then
			s[#s + 1] = "{GIOCATORE}"
		elseif w >= 32 and w < 0x0250 then
			s[#s + 1] = utf8.char(w)
		else
			s[#s + 1] = "<" .. string.format("%04X", w) .. ">"
		end
	end
	return table.concat(s)
end

-- Caratteri visibili per segmento (i segmenti sono separati da CMD_SCROLL, che richiede una pressione)
local function count_segments(cur)
	local segs, n, i = {}, 0, 1
	while i <= #cur do
		if cur[i] == CMD_START then
			if cur[i + 1] == CMD_SCROLL then
				segs[#segs + 1] = n
				n = 0
			end
			i = i + 3 + (cur[i + 2] or 0)
		else
			n = n + 1
			i = i + 1
		end
	end
	segs[#segs + 1] = n
	return segs
end

local function split_pages(words)
	local result, cur = {}, {}

	local function flush()
		while cur[1] == NEWLINE do
			table.remove(cur, 1)
		end
		while cur[#cur] == NEWLINE do
			cur[#cur] = nil
		end
		if #cur > 0 then
			result[#result + 1] = {
				hash  = hash_words(cur),
				text  = decode(cur),
				words = cur,
				segs = count_segments(cur),
			}
		end
		cur = {}
	end

	local i = 1
	while i <= #words do
		if words[i] == CMD_START and words[i + 1] == CMD_PAGE then
			flush()
			i = i + 3 + (words[i + 2] or 0)
		else
			cur[#cur + 1] = words[i]
			i = i + 1
		end
	end
	flush()
	return result
end

--------------------------------------------------------------------------------------------------------------------------------
-- Ricerca dell'audio di una bolla

local function lookup(words)
	local h = hash_words(words)
	if hashToPath[h] then
		return h
	end
	for _, t in ipairs(varTemplates) do
		if match_from(words, t.segs, 1, 1) then
			return t.hash
		end
	end
	return nil
end

-- 1) la bolla cosi' com'e'; 2) se contiene il nome del giocatore, prova a sostituirlo con il segnaposto
-- in tutte le combinazioni (prima tutte le occorrenze): con nomi corti o comuni ("A", "Ale") non si puo'
-- sapere in anticipo quali occorrenze sono davvero il nome e quali fanno parte del testo.
local MAX_NAME_OCC = 8

local function resolve_hash(page)
	local h = lookup(page.words)
	if h then
		return h
	end
	for _, name in ipairs(read_player_names()) do
		local occ = find_occurrences(page.words, name)
		local k = math.min(#occ, MAX_NAME_OCC)
		for mask = (1 << k) - 1, 1, -1 do
			h = lookup(replace_at(page.words, name, occ, mask))
			if h then
				return h
			end
		end
	end
	return page.hash
end

--------------------------------------------------------------------------------------------------------------------------------
-- Audio

local function stop_audio()
	if voicePlayer then
		pcall(function()
			voicePlayer:Stop()
			voicePlayer:Dispose()
		end)
		voicePlayer = nil
	end
end

local function log_miss(pageHash, text)
	if not DEBUG or loggedMisses[pageHash] then
		return
	end
	loggedMisses[pageHash] = true
	local missFile = io.open(MISSES_FILE, "a")
	if missFile then
		missFile:write(pageHash, "\t", text, "\n")
		missFile:close()
	end
end

local function play_page(page)
	stop_audio()
	local path = hashToPath[page.audioHash]
	if not path then
		log_miss(page.hash, page.text)
		return
	end
	local ok, err = pcall(function()
		voicePlayer = SoundPlayer(path)
		voicePlayer:Play()   -- asincrono: non blocca l'emulazione
	end)
	if not ok then
		console.log("ERRORE riproduzione " .. path .. ": " .. tostring(err))
		voicePlayer = nil
	end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Gestione pagine

local function reset_dialog()
	stop_audio()
	currentHash, currentSrc = nil, nil
	pages, pageIdx = {}, 0
	segIdx, segStart, segDone = 1, 0, false
end

local function start_page(idx)
	pageIdx = idx
	segIdx, segStart, segDone = 1, emu.framecount(), false
	local p = pages[idx]
	p.audioHash = p.audioHash or resolve_hash(p)
	if DEBUG then
		local via = (p.audioHash ~= p.hash) and (" (trovata come " .. p.audioHash .. ")") or ""
		console.log(string.format("  Pagina %d/%d -> %s%s = %s", idx, #pages, p.hash, via, hashToPath[p.audioHash] or "NESSUN FILE"))
	end
	play_page(p)
end

local function on_press()
	local p = pages[pageIdx]
	if not p then
		return
	end

	local elapsed     = emu.framecount() - segStart
	local printFrames = p.segs[segIdx] * FRAMES_PER_CHAR

	-- Testo ancora in stampa: la pressione lo completa soltanto
	if not segDone and elapsed < printFrames then
		segDone = true
		if DEBUG then
			console.log(string.format("    pressione durante stampa (%d/%d frame): completa testo", elapsed, printFrames))
		end
		return
	end

	if segIdx < #p.segs then
		-- Scroll dentro la stessa bolla: l'audio continua
		segIdx, segStart, segDone = segIdx + 1, emu.framecount(), false
	elseif pageIdx < #pages then
		start_page(pageIdx + 1)
	else
		-- Ultima bolla chiusa
		stop_audio()
	end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Input

local function button_just_pressed()
	local p = joypad.get()
	local now = (p["A"] or p["B"]) and true or false
	local edge = now and not prevPressed
	prevPressed = now
	return edge
end

--------------------------------------------------------------------------------------------------------------------------------
-- Dialoghi

local function prepare_dialog(words)
	words = normalize_player_cmd(words)
	return words, hash_words(words)
end

local function begin_dialog(words, h, src)
	reset_dialog()
	currentHash, currentSrc = h, src
	pages = split_pages(words)
	if DEBUG then
		local from = (src == "main") and "" or string.format(" [buffer %06X]", src)
		console.log("Dialogo " .. h .. from .. " (" .. #pages .. " pagine) " .. decode(words))
	end
	if #pages > 0 then
		start_page(1)
	end
end

-- Buffer extra da controllare in questo frame: indirizzi fissi + quelli indicati dai puntatori
local function extra_sources()
	local list = {}
	for _, a in ipairs(EXTRA_DIALOG_ADDRS) do
		list[#list + 1] = { key = a, addr = a }
	end
	for _, p in ipairs(EXTRA_DIALOG_PTRS) do
		local v = memory.read_u32_le(p)
		if v >= 0x02000000 and v < 0x02400000 - 0x400 then
			list[#list + 1] = { key = "ptr" .. p, addr = v - 0x02000000 + PTR_TO_MAGIC }
		end
	end
	return list
end

-- Il contenuto gia' presente nei buffer extra (es. dopo un caricamento di stato) non va riprodotto
local function prime_extra(reason)
	for _, src in ipairs(extra_sources()) do
		local addr = src.addr
		local buf = read_dialog(addr)
		local h = nil
		if type(buf) == "table" and #buf > 0 then
			h = select(2, prepare_dialog(buf))
		end
		if DEBUG and reason and h and h ~= extraSeen[src.key] then
			console.log(string.format("  buffer %06X: testo ignorato (%s): %s", addr, reason, decode(buf):sub(1, 60)))
		end
		extraSeen[src.key] = h
	end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Loop principale

local M = {}

function M.init(ctx)
	DEBUG       = ctx.debug
	VOICES      = ctx.base .. "voice_lines/"
	MISSES_FILE = VOICES .. "misses.tsv"
	VAR_FILE    = VOICES .. "variables.tsv"
	memory.usememorydomain("Main RAM")
	load_voices()
	load_templates()
	prime_extra()
	if DEBUG then
		console.log("voice_player: buffer extra " .. #EXTRA_DIALOG_ADDRS .. ", puntatori " .. #EXTRA_DIALOG_PTRS)
	end
end

function M.update()
	local pressed = button_just_pressed()
	local started = false   -- nel frame in cui parte un dialogo la pressione non conta (e' quella che l'ha aperto)

	-- Vince il buffer il cui contenuto e' appena cambiato: durante le chiamate con l'interfono, per esempio,
	-- il buffer normale resta fermo su "<giocatore> risponde all'Interpoke'." mentre il testo della chiamata
	-- arriva in un buffer extra.

	-- Dialoghi normali
	local main = read_dialog(DIALOG_ADDR)
	if type(main) == "table" and #main > 0 then
		local words, h = prepare_dialog(main)
		if h ~= mainSeen then
			mainSeen = h
			if h ~= currentHash then
				begin_dialog(words, h, "main")
				started = true
			end
		end
	elseif main == "CLOSED" then
		mainSeen = nil
		if currentSrc == "main" then
			reset_dialog()
			return
		end
	end

	-- Buffer extra (introduzione, interfono): non vengono azzerati, conta solo quando il contenuto cambia
	for _, src in ipairs(extra_sources()) do
		local buf = read_dialog(src.addr)
		if type(buf) == "table" and #buf > 0 then
			local words, h = prepare_dialog(buf)
			if h ~= extraSeen[src.key] then
				extraSeen[src.key] = h
				if h ~= currentHash then
					begin_dialog(words, h, src.addr)
					started = true
				end
			end
		end
	end

	if pressed and currentHash and not started then
		on_press()
	end
end

-- Caricamento di uno stato: si ferma l'audio e il contenuto attuale dei buffer extra conta come gia' visto
function M.on_loadstate()
	reset_dialog()
	mainSeen = nil   -- un dialogo normale gia' aperto nello stato caricato viene riprodotto
	prime_extra("gia' presente al caricamento dello stato")
end

function M.on_exit()
	stop_audio()
end

return M
