// --- Player Enums ---
enum PLAYER_STATE {
	Root,
    // Parent States
    Grounded,
    InAir,
    
    // Grounded Children
    Idle,
    Walk,
    
    // InAir Children
    Rising,
    Falling,
    
    // Other States
    Dash,
    WallSlide,
}

enum PLAYER_EVENT {
    Move,
    Stop,
    Jump,
    Land,
    Fall,
    Dash,
    Attack,
    HitWall,
    LeaveWall,
    DashEnd,
	WallSlideCooldownEnd,
	WallSlideGraceEnd
}