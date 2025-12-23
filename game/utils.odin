package game

import rl "vendor:raylib"

model_lookat :: proc(from, to, up: rl.Vector3) -> rl.Matrix {
  return rl.MatrixTranslate(
    -from.x,
    -from.y,
    -from.z
  ) * 
  rl.MatrixInvert(rl.MatrixLookAt(
      from,
      to,
      up
  ))
}
