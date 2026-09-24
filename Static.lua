local _, Addon = ...
Addon.Static = Addon.Static or {}

Addon.Static.SchemaVersion = 2

Addon.Static.Defaults = {
    schemaVersion = Addon.Static.SchemaVersion,
    enabled = true,
    message1 = "ty <3",
    message2 = "thx :)",
    message3 = "tyvm <3",
    message4 = "ty :)",
    message5 = "thx :D",
    responseMode = "random",
    replyDelay = 4,
    cooldownDelay = 60,
    debugMode = false,
    excludeGroup = true,
    excludeGuild = true,
}

Addon.Static.Limits = {
    messageLength = 255,
    replyDelayMin = 0,
    replyDelayMax = 30,
    cooldownDelayMin = 0,
    cooldownDelayMax = 3600,
    gracePeriod = 8,
}

Addon.Static.BooleanSettings = {
    enabled = true,
    debugMode = true,
    excludeGroup = true,
    excludeGuild = true,
}

Addon.Static.AuraEvents = {
    SPELL_AURA_APPLIED = true,
    SPELL_AURA_REFRESH = true,
}

-- Every intended Classic rank and group variant
Addon.Static.BuffSpellIds = {
    -- Mark of the Wild
    [1126] = true,
    [5232] = true,
    [6756] = true,
    [5234] = true,
    [8907] = true,
    [9884] = true,
    [9885] = true,
    [21849] = true, -- Gift of the Wild
    [21850] = true,

    -- Thorns
    [467] = true,
    [782] = true,
    [1075] = true,
    [8914] = true,
    [9756] = true,
    [9910] = true,

    -- Arcane Intellect
    [1459] = true,
    [1460] = true,
    [1461] = true,
    [10156] = true,
    [10157] = true,
    [23028] = true, -- Arcane Brilliance

    -- Blessing of Might
    [19740] = true,
    [19834] = true,
    [19835] = true,
    [19836] = true,
    [19837] = true,
    [19838] = true,
    [25291] = true,
    [25782] = true, -- Greater Blessing of Might
    [25916] = true,

    -- Blessing of Kings
    [20217] = true,
    [25898] = true, -- Greater Blessing of Kings

    -- Blessing of Wisdom
    [19742] = true,
    [19850] = true,
    [19852] = true,
    [19853] = true,
    [19854] = true,
    [25290] = true,
    [25894] = true, -- Greater Blessing of Wisdom
    [25918] = true,

    -- Power Word: Fortitude
    [1243] = true,
    [1244] = true,
    [1245] = true,
    [2791] = true,
    [10937] = true,
    [10938] = true,
    [21562] = true, -- Prayer of Fortitude
    [21564] = true,

    -- Unending Breath
    [5697] = true,
}
