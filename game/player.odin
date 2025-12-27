package game
import "core:math"
import rl "vendor:raylib"


Player :: struct {
  model: ^rl.Model,
  position: rl.Vector3,
  velocity: rl.Vector3,
  size: rl.Vector3,
  forward: rl.Vector3,
  up: rl.Vector3,
  right: rl.Vector3,
  throttle: f32,
  max_throttle: f32,
  min_throttle: f32,
  yaw: f32,
  pitch: f32,
  roll: f32,
  p_yaw: f32,
  p_pitch: f32,
  p_roll: f32,
  camera_distance: f32,
  bullets: [dynamic]Bullet,
}

update_localplayer :: proc(camera: ^rl.Camera) {
    frame_delta: f32 = rl.GetFrameTime()

    // rl.DrawModel(local_player.model^, local_player.position, 0.38, rl.WHITE)
    rl.DrawModel(local_player.model^, local_player.position, local_player.size.y*0.02, rl.WHITE)

    for &bullet in local_player.bullets {
      bullet.model.transform = model_lookat(
        bullet.position,
        bullet.position + bullet.forward,
        GLOBAL_UP
      )

      bullet.model.transform = model_lookat({0,0,0}, bullet.velocity, GLOBAL_UP)
      rl.DrawModel(bullet.model^, bullet.position, 1, rl.YELLOW)

      bullet.position += bullet.velocity * frame_delta
    }

    if game_state == .EDITOR {
      return
    }
    // rlgl.DisableDepthMask()
    rl.DrawCubeWiresV(local_player.position, local_player.size, rl.RED)
    // rlgl.EnableDepthMask()

    speed_mag: f32 = 0.2//20//100
    speed_roll: f32 = 2 * frame_delta
    speed: rl.Vector2 = {speed_mag * frame_delta, speed_mag * frame_delta}

    // up_divergence: f32 = rl.Vector3DotProduct(local_player.up, GLOBAL_UP)
    // if up_divergence < 0 && speed.x > 0 {
    //   // speed.x *= -1
    // }

    mouse_delta: rl.Vector2 = rl.GetMouseDelta()// - screen_size/2;

    local_player.p_pitch = local_player.pitch
    local_player.p_yaw = local_player.yaw
    local_player.p_roll = local_player.roll
    local_player.pitch -= mouse_delta.y * speed.y;
    local_player.yaw -= mouse_delta.x * speed.x;

    mouse_scroll := rl.GetMouseWheelMove()
    local_player.camera_distance += mouse_scroll

    // if rl.IsKeyDown(.W) {
    //   local_player.pitch -= speed.y
    // }
    // if rl.IsKeyDown(.S) {
    //   local_player.pitch += speed.y
    // }
    // if rl.IsKeyDown(.A) {
    //   local_player.yaw += speed.x
    // }
    // if rl.IsKeyDown(.D) {
    //   local_player.yaw -= speed.x
    // }
    if rl.IsKeyDown(.E) {
      local_player.roll += speed_roll
    }
    if rl.IsKeyDown(.Q) {
      local_player.roll -= speed_roll
    }

    // local_player.forward = {
    //   math.cos_f32(local_player.pitch*rl.DEG2RAD) * math.sin_f32(local_player.yaw*rl.DEG2RAD),
    //   math.sin_f32(local_player.pitch*rl.DEG2RAD),
    //   math.cos_f32(local_player.pitch*rl.DEG2RAD) * math.cos_f32(local_player.yaw*rl.DEG2RAD),
    // }
    // local_player.up = {
    //   math.cos_f32((local_player.pitch+90)*rl.DEG2RAD) * math.sin_f32(local_player.yaw*rl.DEG2RAD),
    //   math.sin_f32((local_player.pitch+90)*rl.DEG2RAD),
    //   math.cos_f32((local_player.pitch+90)*rl.DEG2RAD) * math.cos_f32(local_player.yaw*rl.DEG2RAD),
    // }
    // local_player.up = rl.Vector3RotateByAxisAngle(local_player.up, local_player.forward, local_player.roll*rl.DEG2RAD)

    // local_player.up = {0, 1, 0}
    // local_player.forward = {0, 0, 1}
    //
    // // local_player.forward = local_player.model.transform

    local_player.forward = rl.Vector3RotateByAxisAngle(local_player.forward, local_player.up, local_player.yaw - local_player.p_yaw)
    local_player.right = rl.Vector3CrossProduct(local_player.up, local_player.forward)

    delta_pitch: f32 = local_player.p_pitch - local_player.pitch
    local_player.up = rl.Vector3RotateByAxisAngle(local_player.up, local_player.right, delta_pitch)
    local_player.forward = rl.Vector3RotateByAxisAngle(local_player.forward, local_player.right, delta_pitch)

    delta_roll: f32 = local_player.roll - local_player.p_roll
    local_player.right = rl.Vector3RotateByAxisAngle(local_player.right, local_player.forward, delta_roll)
    local_player.up = rl.Vector3RotateByAxisAngle(local_player.up, local_player.forward, delta_roll)
    // local_player.up = rl.Vector3CrossProduct(local_player.right, local_player.forward)

    rl.DrawLine3D(local_player.position, local_player.position + local_player.forward * 1, rl.GREEN)
    rl.DrawLine3D(local_player.position, local_player.position + local_player.up * 1, rl.ORANGE)
    rl.DrawLine3D(local_player.position, local_player.position + local_player.right * 1, rl.ORANGE)

    local_player.model.transform = model_lookat(
      local_player.position,
      local_player.position + local_player.forward,
      local_player.up
    )
    local_player.velocity *= 0.1 * frame_delta
    local_player.velocity += local_player.forward * local_player.throttle * 100
    local_player.position += local_player.velocity * frame_delta


    if game_state == .GAME {
      camera.position = local_player.position - (local_player.forward - local_player.up*0.3) * local_player.camera_distance
      camera.up = local_player.up
      camera.target = local_player.position + local_player.up * local_player.camera_distance * 0.3;
      
      // camera.position = local_player.position - (local_player.forward - GLOBAL_UP*0.3) * local_player.camera_distance
      // camera.up = GLOBAL_UP
    } else {
      camera.up = GLOBAL_UP
    }


    throttle_speed : f32 = local_player.max_throttle/100
    if rl.IsKeyDown(.W) {
      local_player.throttle += throttle_speed
      if local_player.throttle > local_player.max_throttle {
        local_player.throttle = local_player.max_throttle
      }
    }
    if rl.IsKeyDown(.S) {
      local_player.throttle -= throttle_speed
      if local_player.throttle < local_player.min_throttle {
        local_player.throttle = local_player.min_throttle
      }
    }

    if rl.IsMouseButtonDown(.LEFT) {
      x: f32 = (len(local_player.bullets) % 2 == 1) ? -1 : 1
      x *= local_player.size.z/2
      append(&local_player.bullets, Bullet{
        position = local_player.position + local_player.right * x,
        velocity = local_player.velocity + local_player.forward * 10,
        forward = local_player.forward,
        speed = 0.1,
        model = &bullet_model
      })
    }

}

free_localplayer :: proc() {
  delete(local_player.bullets)
}
