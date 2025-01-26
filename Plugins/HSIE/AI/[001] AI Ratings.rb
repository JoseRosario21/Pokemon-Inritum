Battle::AI::Handlers::MoveEffectAgainstTargetScore.add("DisableTargetLastMoveUsed",
  proc { |score, move, user, target, ai, battle|
    next Battle::AI::MOVE_USELESS_SCORE if target.has_active_item?(:MENTALHERB)
    # Inherent preference
    score += 5
    # Prefer if the target is locked into using a single move, or will be
    if target.effects[PBEffects::ChoiceBand] ||
       target.has_active_item?([:CHOICEBAND, :CHOICESPECS, :CHOICESCARF]) ||
       target.has_active_ability?(:GORILLATACTICS)
      score += 10
    end
    # Prefer disabling a damaging move
    score += 8 if GameData::Move.try_get(target.battler.lastRegularMoveUsed)&.damaging?
    next score
  }
)