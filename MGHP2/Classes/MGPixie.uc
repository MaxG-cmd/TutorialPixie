class MGPixie extends HChar;

#define DISTANCE(Other) Location - Other.Location
#define PLAYER MGHarry(Level.PlayerHarryActor)
#define PLAY_HURT_SOUND PlaySound(HurtSound, SLOT_Pain, 0.75, false, 4096.0, 1.0, false, false)
#define PLAY_HIT_SOUND PlaySound(SpellHitSound, SLOT_Misc, 0.75, false, 4096.0, 1.0, false, false)
#define PLAY_EXPLODE_SOUND PlaySound(ExplodeSound, SLOT_Misc, 0.75, false, 4096.0, 1.0, false, false)
#define PLAY_TALK_SOUND PlaySound(TalkSound, SLOT_None, 0.75, false, 4096.0, 1.0, false, false)
#define PLAY_BITE_SOUND PlaySound(BiteSound, SLOT_Interact, 0.75, false, 4096.0, 1.0, false, false)
#define PLAY_ATTACK_SOUND PlaySound(AttackSound, SLOT_None, 0.75, false, 4096.0, 1.0, false, false)

// MaxG: Set PatrolPoints to this tag. Points will be randomly picked.
var() Name PathTag;
var() float InvincibilityDuration;

// MaxG: If within this radius, assume the actor has arrived at any given point.
var() float AtPointRadius;

// MaxG: The radius in which this actor will move towards Harry.
var() float ChaseRadius;
var() float ChaseCooldown;

var() float ThrowCooldown;
var() int MaxConsecutiveSpells;

var() int HitsToKill;
var int NumHits;

// MaxG: The actor may bite the player if they are within this radius.
//       After each bite, it will retreat.
var() float BiteRadius;

var() float BiteDamage;


// MaxG: 0-100, use it to make the pixie more aggressive.
//       This gets evaluated each time the pixie reaches a point.
var() float ChanceOfChasing;
var() float ChanceOfThrowing;

var() float MaxStuckVelocity;
var() float MaxStuckTime;

var(MGPixieFX) Class<ParticleFX>  HitBySpellFXClass;
var(MGPixieFX) Class<ParticleFX>  KnockoutFXClass;
var(MGPixieFX) Class<ParticleFX>  ExplodeFXClass;
var(MGPixieFX) Class<ParticleFX>  FlyFXClass;

// MaxG: The default one has the wrong rotation, so it must be corrected.
var(MGPixieFX) Rotator ExplodeFXRotation;

var(MGPixieSounds) Sound AttackSound;
var(MGPixieSounds) Sound BiteSound;
var(MGPixieSounds) Sound TalkSound;
var(MGPixieSounds) Sound HurtSound;
var(MGPixieSounds) Sound SpellHitSound;
var(MGPixieSounds) Sound ExplodeSound;

var float RandomTalkTime;

var ParticleFX FlyFX;

var int it;

var Array<MGKeypoint> PatrolNodes;
var MGKeypoint CurrentDestination;
var MGTimer InvincibilityTimer;
var MGTimer ChaseCooldownTimer;
var MGTimer TalkTimer;
var MGTimer StuckTimer;

// event Tick(float DeltaTime)
// {
//     Super.Tick(DeltaTime);

//     CM("[" $ Name $ "]::GetStateName() ==> " $ GetStateName());
//     CM("[" $ Name $ "]::VSize(Velocity) ==> " $ VSize(Velocity));
// }

function MultiplyVelocity(float Amount)
{
    Velocity *= Vec(Amount, Amount, Amount);
    Acceleration *= Vec(Amount, Amount, Amount);
}

function PopulatePatrolList()
{
	local MGKeypoint P;
    local int list_len;

	if (PathTag != 'None')
	{
        // MaxG: Clear the list.
        for (list_len = 0; list_len < PatrolNodes.Length; list_len++)
        {
            PatrolNodes[list_len] = None;
        }

		// MaxG: Populate the list for later use.
		forEach AllActors(Class'MGKeypoint', P, PathTag)
		{
			PatrolNodes[PatrolNodes.Length] = P;
		}
	}
}

function MGKeypoint ChooseRandomPoint()
{
    local int decision;
		
	decision = Rand(PatrolNodes.Length);
    
    return PatrolNodes[decision];
}

function PlayerCutRelease()
{
    GoToState('FlyAround');
}

event PostBeginPlay()
{
    Super.PostBeginPlay();

    PopulatePatrolList();

    InvincibilityTimer = Spawn(Class'MGTimer');
    ChaseCooldownTimer = Spawn(Class'MGTimer');
    TalkTimer = Spawn(Class'MGTimer');
    StuckTimer = Spawn(Class'MGTimer');

    FlyFX = Spawn(FlyFXClass, None);

    AttachToBone(FlyFX, 'bip01 Spine');
}

// MaxG: Determine if we should go after Harry.
function bool CanChaseHarry()
{
    // MaxG: Must be within the attack radius.
    if ( VSize( DISTANCE(PLAYER) ) <= ChaseRadius )
    {
        // MaxG: Trace to make sure there is no geometry in the way.
        if ( FastTrace(PLAYER.Location, Location) )
        {
            // MaxG: If the timer is off or sufficient time has passed, the cooldown has ended.
            if ( (ChaseCooldownTimer.bTimerSet && ChaseCooldownTimer.SecondsElapsed >= ChaseCooldown) || !ChaseCooldownTimer.bTimerSet)
            {
                ChaseCooldownTimer.StopTimer();
                return true;
            }
        }
    }
}

function GotHit()
{
    // MaxG: Prevent any extra hits.
    if (IsInState('HitFalling') || IsInState('BlowUpAndDie'))
    {
        return;
    }

    if (InvincibilityTimer.SecondsElapsed >= InvincibilityDuration || !InvincibilityTimer.bTimerSet)
    {
        PLAY_HIT_SOUND;
        PLAY_HURT_SOUND;

        if (NumHits >= HitsToKill - 1)
        {
            // MaxG: Do not collide with players anymore. Still want it to be able to land on props.
            SetCollision(true, true, false);
            GoToState('HitFalling');
        }
        else
        {
            InvincibilityTimer.StopTimer();
            NumHits++;
            GoToState('HitBySpell');
        }
    }
}

// MaxG: Instant kill if exploded by a cracker.
event TakeDamage(int Damage, Pawn EventInstigator, vector HitLocation, vector Momentum, name DamageType)
{
    GoToState('HitFalling');
}

event Destroyed()
{
    local Actor A;

    if (Event != 'None')
	{
		forEach AllActors(Class'Actor', A, Event)
		{
			A.Trigger(Self, Self);
		}
	}

    InvincibilityTimer.Destroy();
    ChaseCooldownTimer.Destroy();
    TalkTimer.Destroy();
    
    DetachFromBone(FlyFX);
    FlyFX.ShutDown();

    Super.Destroyed();
}

function bool HandleSpellPixie(optional baseSpell spell, optional Vector vHitLocation)
{
	GotHit();
	
	return true;
}

function bool HandleSpellRictusempra(optional baseSpell spell, optional Vector vHitLocation)
{
    Super.HandleSpellRictusempra(spell, vHitLocation);
    
    GotHit();
    
    return True;
}


function HandleAttackLogic()
{
    local float decision;
    local float sum_chance;

    decision = RandRange(0.0, 100.0);
    sum_chance = 0.0;

    // MaxG: Check the sum chance against the chance of chasing.
    sum_chance += ChanceOfChasing;

    if (decision <= sum_chance)
    {
        GoToState('ChaseHarry');
        return;
    }

    // MaxG: The odds were not in favor of chasing. Check now for throwing.
    sum_chance += ChanceOfThrowing;

    if (decision <= sum_chance)
    {
        GoToState('ThrowSpell');
    }
    else
    {
        GoToState('FlyAround');
    }
}

function bool CanBite(Actor A)
{
    return ( VSize( DISTANCE(A) ) <= BiteRadius );
}

function bool AtPoint(Actor Point)
{
    if ( VSize(DISTANCE(Point)) <= AtPointRadius )
    {
        return true;
    }

    return false;
}

function HandleStuckTimer()
{
    // MaxG: Prevent the actor from getting stuck in a loop.
    if ( VSize(Velocity) <= MaxStuckVelocity && !StuckTimer.bTimerSet )
    {
        StuckTimer.StartTimer();
    }

    if (StuckTimer.SecondsElapsed >= MaxStuckTime)
    {
        GoToState('FlyAround');
    }
}

auto state() Idle
{
    function BeginState()
    {
        SetCollision(false, false, false);
    }

    function EndState()
    {
        SetCollision(true, true, true);
    }

    begin:
        LoopAnim('Idle');
}

state() FlyAround
{
    function BeginState()
    {
        Super.BeginState();
       
        if (!TalkTimer.bTimerSet)
        {
            TalkTimer.StartTimer();
            RandomTalkTime = RandRange(2.0, 12.0);
        }

        if (PatrolNodes.Length <= 0 || PatrolNodes[0] == None)
        {
            PopulatePatrolList();
        }
    }

    event Tick(float DeltaTime)
    {
        Super.Tick(DeltaTime);

        if ( AtPoint(CurrentDestination) )
        {
            HandleAttackLogic();
        }

        if (TalkTimer.SecondsElapsed >= RandomTalkTime)
        {
            PLAY_TALK_SOUND;

            RandomTalkTime = RandRange(2.0, 12.0);
            TalkTimer.StartTimer();
        }
    }

    begin:
        CurrentDestination = ChooseRandomPoint();
        //CM("[" $ Name $ "]::CurrentDestination ==> " $ CurrentDestination);

        LoopAnim('Fly');

        MoveTo(CurrentDestination.Location);
        HandleAttackLogic();
        GoTo('begin');
}

state ChaseHarry
{
    function BeginState()
    {
        Super.BeginState();

        PLAY_ATTACK_SOUND;
    }

    function EndState()
    {
        Super.EndState();

        StuckTimer.StopTimer();
    }

    event Tick(float DeltaTime)
    {
        Super.Tick(DeltaTime);

        if ( VSize( DISTANCE(PLAYER) ) <= BiteRadius )
        {
            TalkTimer.StopTimer();

            GoToState('BitePlayer');
        }

        HandleStuckTimer();
    }


    begin:
        MoveToward(PLAYER);
        Sleep(0.1);
        GoTo('begin');
}

state ThrowSpell
{
    begin:
        for (it = 1; it <= Rand(MaxConsecutiveSpells + 1); it++)
        {
            // MaxG: IDK why this works, but it stops them from moving.
            DesiredSpeed = 0;

            TurnTo(PLAYER.Location);
            PlayAnim('Attack', 3.0);

            MultiplyVelocity(0.0);

            Sleep(0.25);

            SpawnSpell(Class'MGSpellPixieBall', PlayerHarry);

            Sleep(ThrowCooldown);
        }

		GoToState('FlyAround');
}

state BitePlayer
{
    begin:
        MultiplyVelocity(0.05);
        TurnTo(PLAYER.Location);
        PlayAnim('Attack', 3.0);

        // MaxG: Wait for the correct time in the animation.
        //       Should be done with an anim notify event tbh.
        Sleep(0.31);

        if ( CanBite(PLAYER) )
        {
            PLAY_BITE_SOUND;
            PLAYER.TakeDamage(BiteDamage, Pawn(Owner), Location, Velocity, 'Pixie');
        }
        
        GoToState('FlyAround');
}

state HitBySpell
{
    // TODO: Make this sync to the invincibility timer.
    function BeginState()
    {
        Super.BeginState();

        eVulnerableToSpell = SPELL_None;
    }

    function EndState()
    {
        Super.EndState();

        eVulnerableToSpell = SPELL_Rictusempra;
    }

    begin:
        MultiplyVelocity(0.05);
        
        Spawn(HitBySpellFXClass, None, , Location, Rotation);

        InvincibilityTimer.StartTimer();

        PlayAnim('Stun', 1.65);
        FinishAnim();
        GoToState('FlyAround');
        //GoToState('Retreat');
}

state HitFalling
{
    event Landed(Vector HitNormal)
    {
        GoToState('BlowUpAndDie');
    }

    begin:
        SetPhysics(PHYS_Falling);
        MultiplyVelocity(0.75);

        Spawn(KnockoutFXClass, None, , Location, Rotation);
        
        LoopAnim('Stun');
}

state BlowUpAndDie
{
    begin:
        PLAY_EXPLODE_SOUND;
        Spawn( ExplodeFXClass, None, , Location, ExplodeFXRotation );
        Destroy();
}

// MaxG: -_-
state stateMovingToLoc
{
    function EndState()
    {
        Super.EndState();

        AirSpeed = Default.AirSpeed;
    }
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
    AmbientSound=Sound'HPSounds.Critters_sfx.PIX_wingflap_loop'
    AtPointRadius=48.0
    AttackSound=MultiSound'MGSounds.Pixie.PixieAttacks'
    BiteDamage=12.0
    BiteRadius=96.0
    BiteSound=MultiSound'MGSounds.Pixie.PixieBites'
    ChanceOfChasing=20.0
    ChanceOfThrowing=40.0
    ChaseCooldown=2.0
    ChaseRadius=1024
    DrawScale=2
    ExplodeFXClass=Class'HPParticle.PixieExplode'
    ExplodeFXRotation=(Pitch=16384,Roll=0,Yaw=0)
    ExplodeSound=Sound'HPSounds.horklump_mushroom_head_explode'
    FlyFXClass=Class'HPParticle.PixieFlying'
    HitBySpellFXClass=Class'HPParticle.PixieHit'
    HitsToKill=3
    HurtSound=MultiSound'MGSounds.Pixie.PixieOuches'
    InvincibilityDuration=2.85
    KnockoutFXClass=Class'HPParticle.firecracker'
    MaxConsecutiveSpells=2
    MaxStuckTime=2.0
    MaxStuckVelocity=200.0
    Mesh=SkeletalMesh'HPModels.skcornishpixieMesh'
    NumHits=0
    RunAnimName=Fly
    SoundRadius=32
    SpellHitSound=Sound'HPSounds.SPI_hit'
    TalkSound=MultiSound'MGSounds.Pixie.PixieGrumbles'
    ThrowCooldown=0.4
    WalkAnimName=Fly
}