-- Sonidos del juego: los mismos de Escuadrón Cero. Cada valor es el SoundId de un audio de
-- Roblox. Para cambiar uno: en Studio abre la Caja de herramientas (Toolbox) > Audio, haz clic
-- derecho en el sonido y "Copiar ID del recurso". Un texto vacío ("") es "sin sonido".

return {
	-- Disparos: los oyen todos, desde donde está el arma (la clave es el "sound" de cada arma)
	fire = {
		AssaultRifle = "rbxassetid://128799811976358",
		Pistol = "rbxassetid://127604219525464",
		Shotgun = "rbxassetid://113543931016554",
		Sniper = "rbxassetid://135333708100426",
	},
	-- Impacto de la bala en el escenario: lo oyen todos, desde el impacto
	impact = {
		concrete = "rbxassetid://131554175554758", -- también suelo, piedra y todo lo demás
		metal = "rbxassetid://98609496290942",
		wood = "rbxassetid://131036980739699",
	},
	explosion = "rbxassetid://87630300241395", -- las minas (el de la granada)
	empty = "rbxassetid://136205387185309", -- clic al disparar sin balas
	buy = "rbxasset://sounds/electronicpingshort.wav", -- al comprar en la armería
}
