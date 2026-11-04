-- Los sonidos que se repiten mientras pasa algo (Config/Sounds):
--   lowHealth: con poca vida (menos de lowHealthShare de tu vida máxima)
--   alarm: la alarma del laboratorio, mientras tienes el atributo "LabAlarm" (LabService lo quita
--          cuando sales del laboratorio)
--   waveMusic: la música de fondo mientras hay zombis en la ola (atributo "WaveEnemies")
-- Suben y bajan de volumen poco a poco para no cortarse de golpe.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)

local player = Players.LocalPlayer

local Ambience = {}

type Loop = { sound: Sound, volume: number, on: boolean }

local function makeLoop(soundId: string?, volume: number): Loop?
	if not soundId or soundId == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Looped = true
	sound.Volume = 0
	sound.Parent = SoundService
	return { sound = sound, volume = volume, on = false }
end

local function set(loop: Loop?, on: boolean)
	if not loop or loop.on == on then
		return
	end
	loop.on = on
	if on then
		if not loop.sound.IsPlaying then
			loop.sound:Play()
		end
		TweenService:Create(loop.sound, TweenInfo.new(1), { Volume = loop.volume }):Play()
	else
		local fade = TweenService:Create(loop.sound, TweenInfo.new(1.5), { Volume = 0 })
		fade.Completed:Connect(function()
			if not loop.on then
				loop.sound:Stop()
			end
		end)
		fade:Play()
	end
end

function Ambience.Start()
	local lowHealth = makeLoop(Sounds.lowHealth, 0.8)
	local alarm = makeLoop(Sounds.alarm, 0.6)
	local music = makeLoop(Sounds.waveMusic, Sounds.waveMusicVolume or 0.35)
	while true do
		task.wait(0.25)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local alive = humanoid ~= nil and humanoid.Health > 0
		local share = if humanoid and humanoid.MaxHealth > 0 then humanoid.Health / humanoid.MaxHealth else 1
		set(lowHealth, alive and share < (Sounds.lowHealthShare or 0.3))
		set(alarm, player:GetAttribute("LabAlarm") == true)
		set(music, (player:GetAttribute("WaveEnemies") or 0) > 0)
	end
end

return Ambience
