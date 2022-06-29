class MGTutorialPixie extends HChar;

#define PLAY_BITE_SOUND PlaySound(BiteSound, SLOT_Interact, 0.75, false, 4096.0, 1.0, false, false)

var() Name PathTag;

var() float BiteRadius;

var() float BiteDamage;

var() int MaxConsecutiveSpells;

var() int HitsToKill;
// MaxG: Number of times the pixie has been hit.
var int NumHits;

var(MGTutorialPixieFX) Rotator ExplodeFXRotation;
var(MGTutorialPixieFX) Class<ParticleFX> ExplodeFXClass;
var(MGTutorialPixieFX) Class<ParticleFX> FlyFXClass;
var ParticleFX FlyFX;

var(MGTutorialPixieSounds) Sound BiteSound;

var int it;

var Array<MGKeypoint> PatrolNodes;
var MGKeypoint CurrentDestination;

event PostBeginPlay()
{
    Super.PostBeginPlay();

    PopulatePatrolList();

    FlyFX = Spawn(FlyFXClass);

    AttachToBone(FlyFX, 'bip01 Spine');
}

event Destroyed()
{
    Super.Destroyed();

    DetachFromBone(FlyFX);

    FlyFX.ShutDown();
}

function PopulatePatrolList()
{
    local MGKeypoint p;

    foreach AllActors(Class'MGKeypoint', p, PathTag)
    {
        PatrolNodes[PatrolNodes.Length] = p;
    }
}

function MGKeypoint ChooseRandomPoint()
{
    return PatrolNodes[Rand(PatrolNodes.Length)];
}

function bool HandleSpellRictusempra(optional BaseSpell Spell, optional Vector HitLocation)
{
    Super.HandleSpellRictusempra(Spell, HitLocation);

    GotHit();

    return true;
}

function GotHit()
{
    // TODO: Make sure this function just returns if already stunned.

    if (NumHits >= HitsToKill -  1)
    {
        GoToState('HitFalling');
    }
    else
    {
        NumHits++;

        GoToState('HitBySpell');
    }
}

function MultiplySpeed(float Amount)
{
    Velocity *= Vec(Amount, Amount, Amount);
    Acceleration *= Vec(Amount, Amount, Amount);
}

function HandleAttackLogic()
{
    local float decision;

    decision = RandRange(0.0, 100.0);

    if (decision <= 50.0)
    {
        GoToState('FlyAround');
    }
    else
    {
        if (decision <= 75.0)
        {
            GoToState('ChaseHarry');
        }
        else
        {
            GoToState('ThrowSpell');
        }
    }
}

function bool CanBitePlayer()
{
    return ( VSize( Location - PlayerHarry.Location ) <= BiteRadius );
}

auto state() FlyAround
{
    begin:
        CurrentDestination = ChooseRandomPoint();

        LoopAnim('Fly');

        MoveTo(CurrentDestination.Location);
        HandleAttackLogic();
        GoTo('begin');
}

state ChaseHarry
{
    event Tick(float DeltaTime)
    {
        if ( CanBitePlayer() )
        {
            GoToState('Bite');
        }
    }

    begin:
        MoveToward(PlayerHarry);
        Sleep(0.1);
        GoTo('begin');
}

state Bite
{
    begin:
        MultiplySpeed(0.1);
        TurnTo(PlayerHarry.Location);
        PlayAnim('Attack', 3.0);

        Sleep(0.31);

        if ( CanBitePlayer() )
        {
            PLAY_BITE_SOUND;
            PlayerHarry.TakeDamage(BiteDamage, None, Location, Velocity, 'Bite');
        }

        GoToState('FlyAround');
}

state ThrowSpell
{
    begin:
        for (it = 0; it < Rand( MaxConsecutiveSpells + 1 ); it++ )
        {
            DesiredSpeed = 0.0;

            TurnTo(PlayerHarry.Location);
            PlayAnim('Attack', 3.0);

            MultiplySpeed(0.0);

            Sleep(0.25);

            SpawnSpell(Class'SpellEcto', PlayerHarry);

            Sleep(0.4);
        }
        GoToState('FlyAround');
}

state HitBySpell
{
    function BeginState()
    {
        eVulnerableToSpell=SPELL_None;
    }

    function EndState()
    {
        eVulnerableToSpell=SPELL_Rictusempra;
    }

    begin:
        MultiplySpeed(0.1);

        PlayAnim('Stun', 1.65);
        FinishAnim();
        GoToState('FlyAround');
}

state HitFalling
{
    event Landed(Vector HitNormal)
    {
        GoToState('BlowUpAndDie');
    }

    begin:
        SetPhysics(PHYS_Falling);

        LoopAnim('Stun');
}

state BlowUpAndDie
{
    begin:
        Spawn( ExplodeFXClass, None, , Location, ExplodeFXRotation );
        Destroy();
}

defaultproperties
{
    AccelRate=768
	CollisionHeight=24
	CollisionRadius=24
	eVulnerableToSpell=SPELL_Rictusempra
	Physics=PHYS_Flying
	RotationRate=(Pitch=130000,Yaw=130000,Roll=130000)
    AirSpeed=400
    AmbientGlow=64
    DrawScale=2
    Mesh=SkeletalMesh'HPModels.skcornishpixieMesh'
    HitsToKill=3
    MaxConsecutiveSpells=2
    BiteRadius=96.0
    BiteDamage=12.0
    FlyFXClass=Class'HPParticle.PixieFlying'
    ExplodeFXClass=Class'HPParticle.PixieExplode'
    ExplodeFXRotation=(Pitch=16384,Roll=0,Yaw=0)
    BiteSound=Sound'HPSounds.PIX_bite5'
}