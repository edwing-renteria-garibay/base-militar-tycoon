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
	-- Explosiones: la mina suena como la granada y el zombi explosivo como el cohete
	explosion = {
		mine = "rbxassetid://87630300241395",
		zombie = "rbxassetid://134201956270955",
	},
	-- Aviso de acierto: solo lo oye quien dispara, cuando le da a un zombi
	hit = "rbxasset://sounds/electronicpingshort.wav",
	empty = "rbxassetid://136205387185309", -- clic al disparar sin balas
	-- Sin balas, para las armas con su propio clic (las demás usan empty)
	emptyBy = {
		Escopeta = "rbxassetid://136205387185309",
		Francotirador = "rbxassetid://122836641692660",
	},
	buy = "rbxasset://sounds/electronicpingshort.wav", -- al comprar en la armería
}
