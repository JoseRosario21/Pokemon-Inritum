#===============================================================================
# AI Battle Test - Debug menu entries
#
# Everything lives under the existing Battle submenu. Runs are long, so each one
# reports progress through the message window and appends to the log rather than
# replacing it -- comparing today's run with last week's is the point.
#===============================================================================

# Shared progress reporter. Redraws rarely, since a message per battle would
# dominate the runtime of the run it is reporting on.
def pbAIBattleTestProgress(label)
  last_shown = 0
  return proc { |done, total, result|
    if result[:status] != :ok
      Console.echo_warn("[AI test] #{result[:status]}: #{result[:label]} (seed #{result[:seed]})")
    end
    now = System.uptime
    if done == total || now - last_shown > 2.0
      last_shown = now
      Graphics.update
      Input.update
      pbSetWindowText(_INTL("{1}: {2}/{3}", label, done, total))
    end
  }
end

def pbAIBattleTestFinish(results, title)
  pbSetWindowText(nil)
  failures = AIBattleTest.write_log(results, title)
  summary = AIBattleTest.summarise(results)
  if failures.empty?
    pbMessage(_INTL("{1}\\nNo failures.", summary))
  else
    first = failures.first
    pbMessage(_INTL("{1}\\nFirst failure: {2}\\nSeed {3}. Full details in {4}.",
                    summary, first[:error].to_s[0, 80], first[:seed], AIBattleTest::LOG_FILE))
  end
end

#===============================================================================
MenuHandlers.add(:debug_menu, :ai_test_random, {
  "name"        => _INTL("AI test: random battles"),
  "parent"      => :battle_menu,
  "description" => _INTL("Run N headless AI-vs-AI battles with random teams. Logs any crash with its seed."),
  "effect"      => proc {
    params = ChooseNumberParams.new
    params.setRange(1, 500)
    params.setInitialValue(25)
    params.setCancelValue(0)
    count = pbMessageChooseNumber(_INTL("How many battles?"), params)
    next false if count <= 0
    doubles = pbConfirmMessage(_INTL("Run these as double battles?"))
    AIBattleTest.clear_missing_scene_methods
    results = AIBattleTest.run_random_battles(count, doubles,
                                              pbAIBattleTestProgress(_INTL("Random battles")))
    pbAIBattleTestFinish(results, _INTL("Random battles ({1})", doubles ? "doubles" : "singles"))
    next false
  }
})

MenuHandlers.add(:debug_menu, :ai_test_move_sweep, {
  "name"        => _INTL("AI test: every move"),
  "parent"      => :battle_menu,
  "description" => _INTL("Battle through every move in the dex, four at a time. Slow, but catches move-effect crashes."),
  "effect"      => proc {
    total = AIBattleTest.usable_moves.length
    next false if !pbConfirmMessage(_INTL("This runs about {1} battles and will take a while. Continue?",
                                          (total / 4.0).ceil))
    doubles = pbConfirmMessage(_INTL("Run these as double battles?"))
    AIBattleTest.clear_missing_scene_methods
    results = AIBattleTest.run_move_sweep(doubles, pbAIBattleTestProgress(_INTL("Move sweep")))
    pbAIBattleTestFinish(results, _INTL("Move sweep ({1})", doubles ? "doubles" : "singles"))
    next false
  }
})

MenuHandlers.add(:debug_menu, :ai_test_seed, {
  "name"        => _INTL("AI test: replay a seed"),
  "parent"      => :battle_menu,
  "description" => _INTL("Re-run one battle from a seed reported in the log, to reproduce a crash."),
  "effect"      => proc {
    params = ChooseNumberParams.new
    params.setRange(1, 999_999_999)
    params.setInitialValue(1)
    params.setCancelValue(0)
    seed = pbMessageChooseNumber(_INTL("Seed to replay?"), params)
    next false if seed <= 0
    doubles = pbConfirmMessage(_INTL("Was it a double battle?"))
    result = AIBattleTest.replay_seed(seed, doubles)
    result[:label] = _INTL("replay of seed {1}", seed)
    pbAIBattleTestFinish([result], _INTL("Seed replay"))
    next false
  }
})
