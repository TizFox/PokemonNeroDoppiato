--------------------------------------------------------------------------------------------------------------------------------
-- Scritta "Doppiato" sotto il logo "Pokemon Versione Nera" (caricato da voice_player.lua)
--
-- CALIBRAZIONE (CFG.calib = true), tasti della tastiera:
--   F9        mostra / nasconde la scritta a mano (per posizionarla con il gioco in pausa sul logo)
--   I J K L   sposta su / sinistra / giu' / destra (tieni premuto Shift per andare piu' veloce)
--   U / O     rimpicciolisce / ingrandisce
--   F10       scrive in console i valori da copiare in CFG
--
-- TRIGGER: la scritta compare quando TUTTI gli indirizzi di CFG.trigger hanno il valore indicato
-- (valore nil = "qualsiasi valore diverso da 0"). Indirizzi trovati con Tools > RAM Search.
--------------------------------------------------------------------------------------------------------------------------------

local CFG = {
	text    = "DOPPIATO",
	x       = 128,
	y       = 104,
	size    = 12,
	font    = "Arial",
	style   = "italic",       -- regular / bold / italic
	color   = 0xebebeb,
	outline = 0x383838,
	fade_in = 40,
	fade_out = 40,

	-- Firma del logo: { indirizzo Main RAM, byte (1/2/4), valore }
	-- Sono voci della mappa dei tile del logo (numeri consecutivi 64..96 e 160..191).
	trigger = {
		{ 0x269FEC, 2, 64 },    -- primo tile della prima parte
		{ 0x26A02C, 2, 96 },    -- ultimo tile della prima parte
		{ 0x26A0AC, 2, 160 },   -- primo tile della seconda parte
		{ 0x26A0EA, 2, 191 },   -- ultimo tile della seconda parte
	},
}

local M = {}
local alpha, manual, wasOn, drewLast = 0, false, false, false
local prevKeys = {}

local function read_value(addr, size)
	if size == 4 then
		return memory.read_u32_le(addr, "Main RAM")
	elseif size == 2 then
		return memory.read_u16_le(addr, "Main RAM")
	end
	return memory.read_u8(addr, "Main RAM")
end

local function triggered()
	if not CFG.trigger or #CFG.trigger == 0 then
		return false
	end
	for _, t in ipairs(CFG.trigger) do
		local v = read_value(t[1], t[2] or 1)
		if t[3] == nil then
			if v == 0 then return false end
		elseif v ~= t[3] then
			return false
		end
	end
	return true
end

local function argb(a, rgb)
	return (math.floor(a) << 24) | (rgb & 0xFFFFFF)
end

local function draw(a)
	-- coordinate DS -> coordinate del buffer (in caso di risoluzione interna aumentata)
	local s = client.bufferwidth() / 256
	local x, y, size = CFG.x * s, CFG.y * s, CFG.size * s
	local o = math.max(1, math.floor(s))
	for _, d in ipairs({ { -o, 0 }, { o, 0 }, { 0, -o }, { 0, o }, { -o, -o }, { o, o }, { -o, o }, { o, -o } }) do
		gui.drawText(x + d[1], y + d[2], CFG.text, argb(a, CFG.outline), 0x00000000, size, CFG.font, CFG.style, "center")
	end
	gui.drawText(x, y, CFG.text, argb(a, CFG.color), 0x00000000, size, CFG.font, CFG.style, "center")
end

function M.update()
	local on = triggered()
	if CFG.calib and on ~= wasOn then
		console.log("Doppiato: trigger " .. (on and "ATTIVO" or "spento") .. " al frame " .. emu.framecount())
	end
	wasOn = on
	local show = manual or on
	if show then
		alpha = math.min(255, alpha + 255 / math.max(1, CFG.fade_in))
	else
		alpha = math.max(0, alpha - 255 / math.max(1, CFG.fade_out))
	end
	if manual then
		alpha = 255   -- in calibrazione niente dissolvenza
	end

	-- BizHawk lascia a schermo l'ultimo disegno: si cancella ogni frame, altrimenti
	-- i disegni si sommano (dissolvenza troppo rapida) e resta una scritta semitrasparente
	if drewLast then
		gui.clearGraphics()
		drewLast = false
	end
	if alpha >= 1 then
		draw(alpha)
		drewLast = true
	end
end

function M.init(ctx)
	CFG.calib = ctx.debug
end

local function clear()
	alpha, manual, wasOn = 0, false, false
	if drewLast then
		gui.clearGraphics()
		drewLast = false
	end
end

M.on_loadstate = clear
M.on_exit = clear

return M
