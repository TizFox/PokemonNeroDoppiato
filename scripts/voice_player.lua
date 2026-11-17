luanet.load_assembly("System")
local SoundPlayer = luanet.import_type("System.Media.SoundPlayer")

local VOICES      = "voice_lines/"
local INDEX_FILE  = VOICES .. "index.tsv"    -- generato da extract_script.py
local MISSES_FILE = VOICES .. "misses.tsv"   -- pagine senza wav (solo con DEBUG)
local DEBUG = true

-- Memory setup
memory.usememorydomain("Main RAM")
local DIALOG_ADDR, DIALOG_WORDS = 0x25AF20, 128
local NAME_ADDRS = { 0x24F82C, 0x24F6C8 }    -- nome giocatore: in gioco / durante l'intro
local NAME_PLACEHOLDER = 0xE001              -- deve coincidere con PLACEHOLDER di extract_script.py

-- State
local voicePlayer = nil
local currentHash = nil
local pageHashes, pageTexts, pageIdx = {}, {}, 0
local prevPressed = false
local loggedMisses = {}

---------------------------------------------------------------- indice wav
local hashToPath = {}                        -- hash di pagina -> percorso completo del wav

local function load_index()
  local fh = io.open(INDEX_FILE, "r")
  if not fh then
    console.log("ERRORE: indice non trovato: " .. INDEX_FILE)
    return
  end
  local count = 0
  for line in fh:lines() do
    local h, relPath = line:match("^(%x+)\t(.-)\r?$")
    if h then
      hashToPath[h] = VOICES .. relPath
      count = count + 1
    end
  end
  fh:close()
  console.log("Indice caricato: " .. count .. " voci")
end
load_index()

---------------------------------------------------------------- lettura RAM
local function read_dialog()
  local h1 = memory.read_u16_le(DIALOG_ADDR)
  local h2 = memory.read_u16_le(DIALOG_ADDR + 2)
  if h1 == 0 and h2 == 0 then return "CLOSED" end
  if h1 ~= 0xD2EC or h2 ~= 0xB6F8 then return nil end
  if memory.read_u16_le(DIALOG_ADDR + 4) == 0xFFFF then return nil end
  local words = {}
  for i = 2, DIALOG_WORDS - 1 do
    local w = memory.read_u16_le(DIALOG_ADDR + i * 2)
    if w == 0xFFFF then break end
    words[#words + 1] = w
  end
  return words
end

local function read_name_at(addr)
  local name = {}
  for i = 0, 9 do
    local w = memory.read_u16_le(addr + i * 2)
    if w == 0xFFFF or w == 0 then break end
    name[#name + 1] = w
  end
  return name
end

local function read_player_names()
  local names = {}
  for _, addr in ipairs(NAME_ADDRS) do
    local n = read_name_at(addr)
    if #n >= 2 then names[#names + 1] = n end
  end
  return names
end

-- sostituisce le occorrenze del nome del giocatore con la word segnaposto
local function replace_player_name(words, name)
  local out, i = {}, 1
  while i <= #words do
    local match = true
    for j = 1, #name do
      if words[i + j - 1] ~= name[j] then match = false; break end
    end
    if match then
      out[#out + 1] = NAME_PLACEHOLDER
      i = i + #name
    else
      out[#out + 1] = words[i]
      i = i + 1
    end
  end
  return out
end

---------------------------------------------------------------- hash e testo
-- FNV-1a 64 bit sulle word u16 (little endian). Richiede Lua 5.4. Identico a fnv64() in Python.
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

-- spezza il buffer sui comandi F000 BE01 n; ritorna gli hash e i testi delle pagine
local function split_pages(words)
  local hashes, texts, cur = {}, {}, {}

  local function flush()
    -- toglie gli FFFE residui a inizio e fine pagina
    while cur[1] == 0xFFFE do table.remove(cur, 1) end
    while cur[#cur] == 0xFFFE do cur[#cur] = nil end
    if #cur > 0 then
      hashes[#hashes + 1] = hash_words(cur)
      texts[#texts + 1]   = decode(cur)
    end
    cur = {}
  end

  local i = 1
  while i <= #words do
    if words[i] == 0xF000 and words[i + 1] == 0xBE01 then
      flush()
      i = i + 3 + (words[i + 2] or 0)   -- F000, BE01, nargs, + argomenti
    else
      cur[#cur + 1] = words[i]
      i = i + 1
    end
  end
  flush()
  return hashes, texts
end

---------------------------------------------------------------- audio
local function stop_audio()
  if voicePlayer then
    voicePlayer:Stop()
    voicePlayer = nil
  end
end

local function log_miss(pageHash, text)
  if not DEBUG or loggedMisses[pageHash] then return end
  loggedMisses[pageHash] = true
  local fh = io.open(MISSES_FILE, "a")
  if fh then
    fh:write(pageHash, "\t", text, "\n")
    fh:close()
  end
end

local function play_page(pageHash, text)
  stop_audio()
  local audioFile = hashToPath[pageHash]
  if audioFile then
    voicePlayer = SoundPlayer(audioFile)
    voicePlayer:Play()
  else
    log_miss(pageHash, text)
  end
end

---------------------------------------------------------------- input
local function button_just_pressed()
  local p = joypad.get()
  local now = (p["A"] or p["B"]) and true or false
  local edge = now and not prevPressed
  prevPressed = now
  return edge
end

---------------------------------------------------------------- loop
event.onframeend(function()
  local pressed = button_just_pressed()

  local dialog = read_dialog()
  if dialog == "CLOSED" then
    stop_audio(); currentHash = nil; pageHashes = {}; pageTexts = {}; pageIdx = 0
    return
  end

  if dialog ~= nil and #dialog > 0 then
    for _, name in ipairs(read_player_names()) do
      dialog = replace_player_name(dialog, name)
    end
    local dialogHash = hash_words(dialog)
    if dialogHash ~= currentHash then
      -- nuovo dialogo
      currentHash = dialogHash
      pageHashes, pageTexts = split_pages(dialog)
      pageIdx = 1
      console.log("LINE " .. dialogHash .. " (" .. #pageHashes .. " pagine) " .. decode(dialog))
      if pageHashes[1] then
        console.log("  page 1 -> " .. pageHashes[1] .. " = " .. hashToPath[pageHashes[1]])
        play_page(pageHashes[1], pageTexts[1])
      end
      return -- evita che lo stesso A che apre il dialogo faccia avanzare
    end
  end

  -- dialogo in corso: A/B = prossima bolla
  if pressed and currentHash then
    if pageIdx < #pageHashes then
      pageIdx = pageIdx + 1
      console.log("  page " .. pageIdx .. " -> " .. pageHashes[pageIdx])
      play_page(pageHashes[pageIdx], pageTexts[pageIdx])
    else
      stop_audio() -- ultima bolla: il dialogo si sta chiudendo
    end
  end
end)
