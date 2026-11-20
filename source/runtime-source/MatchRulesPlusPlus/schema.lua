-- The game's rules (their names and kinds, from its UIParameters) and Match Rules ++'s extra rules.
local M={}
-- Each group of the game's rules: category, id (its type), the property of its parameters, and its
-- rows' names (a bool marked ?, a whole number #, else a float).
M.groups = {}
for _, g in ipairs({
    {'match',1,'GlobalMatchParameters','GlobalGravity EnableBuffDrops? EnableWardrobe?'},
    {'match',2,'HunterMatchParameters','StaminaEnabled? CooldownMultiplier MovementSpeedMultiplier JumpHeightMultiplier PlayerSizeMultiplier DamageMultiplier VoicePitch'},
    {'match',3,'WitchMatchParameters','CooldownMultiplier MaxHealthMultiplier MaxManaMultiplier ManaRegenMultiplier MovementSpeedMultiplier JumpHeightMultiplier PlayerSizeMultiplier VoicePitch'},
    {'skills',1,'Chicken','IsListed? Cooldown InitialVelocity VelocityAfterLanding CheckRadius Duration Scale Pitch'},
    {'skills',2,'Hook','IsListed? Cooldown Damage HookVelocity HookDuration PullStrength PullDuration'},
    {'skills',3,'Cannonball','IsListed? Cooldown PassiveJump AirControl GravityScale ImpactSizeSmall ImpactSizeMedium ImpactSizeBig ImpactForceSmall ImpactForceMedium ImpactForceBig ImpactDamageSmall ImpactDamageMedium ImpactDamageBig ShockwaveSizeSmall ShockwaveSizeMedium ShockwaveSizeBig ShockwaveForceSmall ShockwaveForceMedium ShockwaveForceBig'},
    {'skills',4,'Garlic','IsListed? Cooldown Velocity Radius Duration'},
    {'skills',5,'Trap','IsListed? Cooldown SuckDuration SlowTime WitchVacuumRadius PropVacuumRadius PullForceWitch PullForceProp'},
    {'skills',6,'PowerBall','IsListed? Cooldown Damage MaxSpeed Acceleration CanJumpDelay JumpForce FallAcceleration'},
    {'skills',7,'Decoy','IsListed? ActivationManaCost ManaCostPerSecond DecoyHealth'},
    {'skills',8,'Mushroom','IsListed? Cooldown ActivationManaCost ProjectileVelocity SplitProjectileVelocity SplitIterations# SplitCount# ConfuseDuration MushroomDuration EffectRadius MushroomSize MiniMushroomSize'},
    {'skills',9,'Fly','IsListed? ActivationManaCost ManaCostPerSecond ForceMultiplier'},
    {'skills',10,'JumpScare','IsListed? Cooldown ActivationManaCost StartVelocity Acceleration ScalePerSecond BlindDurationMinimum BlindDurationMaximum FlightDuration'},
    {'skills',11,'Possess','IsLIsted? Cooldown ActivationManaCost Range'},
    {'skills',12,'FlyingEye','IsLIsted? ActivationManaCost ManaCostPerSecond MaxSpeed Acceleration Deceleration Scale'},
    {'skills',13,'Potato','IsListed? Cooldown ManualFireCooldown StaminaCost Damage Velocity GravityScale PushStrength ProjectileHealth ProjectileScale Projectiles# Spread'},
    {'skills',14,'Melee','IsListed? Cooldown ChargeTime DamageUncharged DamageCharged ForceUncharged ForceCharged DistanceUncharged DistanceCharged'},
    {'skills',15,'Train','IsListed? Cooldown Damage Velocity GravityScale Duration'},
    {'powerups',1,'HunterCooldownReduction','IsEnabled? BuffLength CooldownMultiplier'},
    {'powerups',2,'HunterRapidFire','IsEnabled? BuffLength StaminaCostMultiplier CooldownMultiplier'},
    {'powerups',3,'HunterSpeedBoost','IsEnabled? BuffLength SpeedMultiplier'},
    {'powerups',4,'HunterDetection','IsEnabled? BuffLength Scale CheckRadius Pitch'},
    {'powerups',5,'WitchManaBoost','IsEnabled? BuffLength ManaRegenMultiplicator'},
    {'powerups',6,'WitchHeal','IsEnabled? HealAmmount OverHealReductionMultiplier'},
    {'powerups',7,'WitchInvisible','IsEnabled? BuffLength'},
    {'powerups',8,'WitchConfusionWave','IsEnabled? ConfuseDuration EffectRadius'},
    {'mods',1,'MoveOrDamage','IsEnabled? DamagePerInterval IntervalBetweenDamages SecondsUntilDamageStarts VelocityToAvoidDamage SilentDamage? EnableTaunting?'},
    {'mods',2,'DissolvingProps','IsEnabled? IntervalBetweenDissolves PercentageOfPropsDissolved NumberOfIntervals#'},
    {'mods',3,'PropRetaliation','IsEnabled? SingleTargetReflectionRatio AreaDamageReflectionRatio'},
}) do
    local rows = {}
    for name, mark in g[4]:gmatch('(%w+)([?#]?)') do rows[#rows + 1] = {name = name, kind = mark == '?' and 'bool' or mark == '#' and 'int' or 'float'} end
    M.groups[#M.groups + 1] = {category = g[1], id = g[2], property = g[3], rows = rows}
end
M.collections = {
    match = {field='MatchRules', type='MatchRuleType_2_7A33ED664F8C0FBEE1C782B8057AEA07', params='UIParameters_6_D7D219FA47CFCDF8FCA3DB9DBCF39E11', rep=34},
    skills = {field='SkillRules', type='SkillType_2_5808B66B468AC4EC8E4F7096273ED505', params='SkillParameters_6_41DDEB6C424E37EF4C61239795AF12B0', setter='AddSkillRule', rep=32},
    mods = {field='GameModifiers', type='ModifierType_2_FEC4E34148D09164EA058CBDDCBE4C7F', params='UIParameters_6_270A78AB4625673AD2C87194A200889D', setter='AddGameModifier', rep=35},
    powerups = {field='PowerupRules', type='PowerupType_5_07F0F6FF44288141C9331F8C816DF5AF', params='PowerupParameters_6_855163784BFC03D7EC9FB8B8D2C10128', setter='AddPowerupRule', rep=37}
}
-- place: the game's own rules page section they show in (Match page lists: GlobalSliderList,
-- HunterSliderList, WitchSliderList), or the skill page of a skill type (11 Possess, 13 Potato).
M.extras = {
    {key='pickupMin', place='WitchSliderList', label='Powerup spawn delay (s)', min=1, step=1, integer=true, initial=30, sliderMin=5, sliderMax=120},
    {key='pickupJitter', place='WitchSliderList', label='Powerup spawn random extra (s)', min=0, step=1, integer=true, initial=10, sliderMin=0, sliderMax=60},
    {key='powerupLifetime', place='GlobalSliderList', label='Powerup lifetime (s)', help='How long a power-up stays before it goes; 0: as long as the game keeps it.', min=0, step=1, integer=true, initial=0, sliderMin=0, sliderMax=120},
    {key='roundDelay', place='GlobalSliderList', label='Time between rounds (s)', min=1, step=1, integer=true, initial=22, sliderMin=5, sliderMax=60},
    {key='trapThrowSpeed', place=5, label='Throw speed multiplier', min=.01, step=.05, initial=1, sliderMin=.25, sliderMax=3},
    {key='trapDelay', place=5, label='Activation delay after landing (s)', min=0, step=.05, initial=.25, sliderMin=0, sliderMax=3},
    {key='trapSlow', place=5, label='Slowed speed multiplier', min=0, sliderMax=1, step=.05, initial=.75},
    {key='manaDrain', place=5, label='Mana drained per second in a trap', min=0, step=1, initial=20, sliderMin=0, sliderMax=100},
    {key='chickenStamina', place=1, label='Stamina cost', min=0, max=1, step=.01, initial=0},
    {key='hookStamina', place=2, label='Stamina cost', min=0, max=1, step=.01, initial=0},
    {key='cannonStamina', place=3, label='Stamina cost', min=0, max=1, step=.01, initial=0},
    {key='garlicStamina', place=4, label='Stamina cost', min=0, max=1, step=.01, initial=0},
    {key='trapStamina', place=5, label='Stamina cost', min=0, max=1, step=.01, initial=0},
    {key='powerballStamina', place=6, label='Stamina cost', min=0, max=1, step=.01, initial=0},
    {key='meleeStamina', place=14, label='Stamina cost', min=0, max=1, step=.01, initial=0},
    {key='trainStamina', place=15, label='Stamina cost', min=0, max=1, step=.01, initial=0},
    {key='chickenSparks', kind='bool', place=1, label='Point at found witches', initial=false},
    {key='detectionSparks', kind='bool', place='powerup:4', label='Point at found witches', initial=false},
    {key='staminaRecharge', place='HunterSliderList', label='Hunter stamina recharge per second', min=0, step=1, initial=10, sliderMin=0, sliderMax=50},
    {key='cooldownMin', place='GlobalSliderList', label='Minimum cooldown (s)', min=.01, step=.02, initial=.02, sliderMin=0.02, sliderMax=5},
    {key='deadDecoys', kind='bool', place=7, label='Dead witches throw decoys', help='A killed witch throws decoys with her two skill keys while she waits: a running witch, or a prop.', initial=false},
    {key='deadDecoyCooldown', place=7, label='Dead witch decoy cooldown (s)', min=.1, step=1, initial=8, sliderMin=1, sliderMax=30},
    {key='keepAbandoned', kind='bool', place=11, label='Keep abandoned props', initial=false},
    {key='possessionLifetime', place=11, label='Abandoned prop lifetime (s)', min=.1, step=.5, initial=5, sliderMin=1, sliderMax=60},
    {key='propForce', place='WitchSliderList', label='Prop push strength multiplier', min=.01, step=.05, initial=1, sliderMin=0.05, sliderMax=3},
    {key='propAirForce', place='WitchSliderList', label='Prop push strength in air multiplier', min=.01, step=.05, initial=1, sliderMin=0.05, sliderMax=3},
    {key='propMaxSpeed', place='WitchSliderList', label='Prop speed limit multiplier', min=.01, step=.05, initial=1, sliderMin=0.05, sliderMax=3},
    {key='propJumpForce', place='WitchSliderList', label='Prop jump strength multiplier', min=.01, step=.05, initial=1, sliderMin=0.05, sliderMax=3},
    {key='propSpeed', place='WitchSliderList', label='Prop speed multiplier', min=.01, step=.05, initial=1, sliderMin=0.05, sliderMax=3},
    {key='propMass', place='WitchSliderList', label='Prop weight multiplier', min=.01, step=.05, initial=1, sliderMin=0.05, sliderMax=3},
    {key='hunterGravity', place='HunterSliderList', label='Hunter gravity multiplier', min=0, step=.05, initial=1, sliderMin=0.05, sliderMax=3},
    {key='witchGravity', place='WitchSliderList', label='Witch gravity multiplier', min=0, step=.05, initial=1, sliderMin=0.05, sliderMax=3},
    {key='padImpulse', place='GlobalSliderList', label='Spring pad impulse multiplier', min=0, step=.05, initial=1, sliderMin=0.05, sliderMax=3},
    {key='hunterAirControl', place='HunterSliderList', label='Hunter air control (without Cannonball)', min=0, sliderMax=1, step=.05, initial=.05},
    {key='witchAirControl', place='WitchSliderList', label='Witch air control', min=0, sliderMax=1, step=.05, initial=.2}
}
return M
