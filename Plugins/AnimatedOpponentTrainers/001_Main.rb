#===============================================================================
# Animated Opponent Trainers
#
# Opponent trainer front sprites animate when their bitmap is a horizontal
# strip of frames.  The convention mirrors the player back sprite:
#   - Each frame is square (frame width == bitmap height, i.e. 180×180).
#   - A sprite with width >= height*2 (i.e. >= 360px wide) is treated as
#     multi-frame and will cycle through its frames as an idle animation.
#   - Single-frame sprites (width < height*2) display as normal — no change.
#
# ANIM_PERIOD: game frames between animation frame advances.
# At 40 fps the default of 8 gives ~5 fps animation, which looks natural.
#===============================================================================
class Battle::Scene
  TRAINER_ANIM_PERIOD = 8

  #-----------------------------------------------------------------------------
  # Patch pbCreateTrainerFrontSprite:
  #   detect multi-frame sprites, clamp src_rect to one frame, store metadata.
  #-----------------------------------------------------------------------------
  alias_method :aot_orig_pbCreateTrainerFrontSprite, :pbCreateTrainerFrontSprite

  def pbCreateTrainerFrontSprite(idxTrainer, trainerType, numTrainers = 1)
    aot_orig_pbCreateTrainerFrontSprite(idxTrainer, trainerType, numTrainers)
    sprite = @sprites["trainer_#{idxTrainer + 1}"]
    return unless sprite&.bitmap && !sprite.bitmap.disposed?

    frame_w     = sprite.bitmap.height          # each frame is square
    frame_count = sprite.bitmap.width / frame_w
    return if frame_count < 2                   # single frame — nothing to do

    sprite.src_rect.x     = 0
    sprite.src_rect.width = frame_w
    sprite.ox             = frame_w / 2

    @trainer_anim ||= {}
    @trainer_anim[idxTrainer + 1] = { frame: 0, count: frame_count, timer: 0 }
  end

  #-----------------------------------------------------------------------------
  # Patch pbFrameUpdate: advance animated opponent trainer frames each tick.
  #-----------------------------------------------------------------------------
  alias_method :aot_orig_pbFrameUpdate, :pbFrameUpdate

  def pbFrameUpdate(cw = nil)
    aot_orig_pbFrameUpdate(cw)
    return unless @trainer_anim
    @trainer_anim.each do |idx, anim|
      sprite = @sprites["trainer_#{idx}"]
      next unless sprite&.visible && sprite.bitmap && !sprite.bitmap.disposed?
      anim[:timer] += 1
      next if anim[:timer] < TRAINER_ANIM_PERIOD
      anim[:timer] = 0
      anim[:frame] = (anim[:frame] + 1) % anim[:count]
      sprite.src_rect.x = anim[:frame] * sprite.src_rect.width
    end
  end
end
