--------------------------------------------------------------------------------------------------------------------------------
-- Pokemon Nero Doppiato - punto di ingresso per BizHawk (lanciato da PokemonNeroDoppiato.bat)
--
-- Carica i moduli in scripts/modules/ e gli passa gli eventi dell'emulatore.
-- Ogni modulo e' un file che restituisce una tabella con (tutte opzionali):
--   init(ctx)        all'avvio; ctx = { base = cartella scripts/, debug = DEBUG }
--   update()         a ogni frame
--   on_loadstate()   dopo il caricamento di uno stato
--   on_exit()        alla chiusura dello script
-- Se un modulo va in errore viene disattivato solo lui, gli altri continuano.
--------------------------------------------------------------------------------------------------------------------------------

local DEBUG = true   -- log in console, misses.tsv, tasti di calibrazione. Mettere false nel pacchetto finale.

local MODULES = {
	"voice_player",
	"logo",
}

--------------------------------------------------------------------------------------------------------------------------------

local function script_dir()
	local ok, info = pcall(debug.getinfo, 1, "S")
	if ok and info and info.source and info.source:sub(1, 1) == "@" then
		return info.source:sub(2):match("^(.*[/\\])") or ""
	end
	return ""
end

local ctx = { base = script_dir(), debug = DEBUG }
local active = {}   -- { name, mod }

local function disable(entry, what, err)
	console.log("ERRORE nel modulo " .. entry.name .. " (" .. what .. "), disattivato: " .. tostring(err))
	for i, e in ipairs(active) do
		if e == entry then
			table.remove(active, i)
			break
		end
	end
end

local function call_all(fnName)
	-- copia della lista: un modulo puo' essere rimosso durante il giro
	local list = { table.unpack(active) }
	for _, entry in ipairs(list) do
		local fn = entry.mod[fnName]
		if fn then
			local ok, err = pcall(fn)
			if not ok then
				disable(entry, fnName, err)
			end
		end
	end
end

for _, name in ipairs(MODULES) do
	local ok, mod = pcall(dofile, ctx.base .. "modules/" .. name .. ".lua")
	if not ok then
		console.log("ERRORE caricamento modulo " .. name .. ": " .. tostring(mod))
	elseif type(mod) ~= "table" then
		console.log("ERRORE: il modulo " .. name .. " non restituisce una tabella")
	else
		local okInit, err = true, nil
		if mod.init then
			okInit, err = pcall(mod.init, ctx)
		end
		if okInit then
			active[#active + 1] = { name = name, mod = mod }
			console.log("Modulo avviato: " .. name)
		else
			console.log("ERRORE avvio modulo " .. name .. ": " .. tostring(err))
		end
	end
end

event.onframeend(function() call_all("update") end, "doppiato_frame")
event.onloadstate(function() call_all("on_loadstate") end, "doppiato_loadstate")
event.onexit(function() call_all("on_exit") end, "doppiato_exit")

console.log("Pokemon Nero Doppiato avviato (" .. #active .. "/" .. #MODULES .. " moduli" .. (DEBUG and ", debug" or "") .. ")")
