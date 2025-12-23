package planet_generator
import "core:fmt"
import "core:math"
import "core:mem"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"
import rand "core:math/rand"
import noise "core:math/noise"

camera_zoom_factor: f32 = 50

noise_sample_scale_x: f32 = 1
noise_sample_scale_y: f32 = 1

color: rl.Color = {0, 0, 0, 255}
water_color: rl.Color = {0, 0, 210, 255}
color_weight: f32 = 0.176

oceans: bool = true

update_camera :: proc(camera: ^rl.Camera, dt: f32) {
    rl.UpdateCamera(camera, .THIRD_PERSON)
    scroll: f32 = -rl.GetMouseWheelMove() * dt * 60 * 0.05
    camera_dir: rl.Vector3 = camera.position
    camera_len: f32 = rl.Vector3Length(camera_dir)
    normalized_camera_dir: rl.Vector3 = camera_dir / camera_len
    zoom_factor: f32 = 1 + (camera_len / camera_zoom_factor)
    camera.position = normalized_camera_dir * (camera_len + scroll * zoom_factor)
}

mouse_enabled: bool = false

regenerate_planet :: proc(model: ^rl.Model) {
  reload_model(model)
  fmt.printf("Number of meshes %i \n", model.meshCount)
  if model.meshCount < 1 {
    fmt.println("ERROR modifying a model with no mesh")
    return
  }

  mesh: rl.Mesh = model.meshes[0]

  for i in 0..<mesh.vertexCount {
    x: f32 = mesh.vertices[i*3]
    y: f32 = mesh.vertices[i*3+1]
    z: f32 = mesh.vertices[i*3+2]

    leng: f32 = rl.Vector3Length({x, y, z})
    norm: rl.Vector3 = {x, y, z} / leng

    theta: f32 = math.atan2(norm.y, norm.x)

    phi: f32 = math.acos(norm.z / leng)

    theta = theta * noise_sample_scale_x
    phi = phi * noise_sample_scale_y

    scl: f64 = 0.6
    scl_det: f64 = 1.5
    noise_sample: noise.Vec3 = noise.Vec3{f64(norm.x * noise_sample_scale_x), f64(norm.y * noise_sample_scale_y), f64(norm.z * noise_sample_scale_x)}
    disp: f32 = noise.noise_3d_improve_xy(100, noise_sample * scl) * 0.4
    disp += noise.noise_3d_improve_xy(200, noise_sample * scl_det) * 0.35

    mesh.texcoords2[i*2] = disp
    mesh.texcoords2[i*2+1] = 0 // Can encode something useful here aswell

    if disp < 0 && oceans {
      disp = 0
    }
    leng += disp
    final: rl.Vector3 = norm * leng
    mesh.vertices[i*3]   = final.x
    mesh.vertices[i*3+1] = final.y
    mesh.vertices[i*3+2] = final.z

  }

  rl.UpdateMeshBuffer(mesh, 0, mesh.vertices, mesh.vertexCount * size_of(f32) * 3, 0)
  rl.UpdateMeshBuffer(mesh, 5, mesh.texcoords2, mesh.vertexCount * size_of(f32) * 2, 0)
}

reload_model :: proc(base: ^rl.Model) {
  albedo := base.materials[0].maps[rl.MaterialMapIndex.ALBEDO].texture
  normal := base.materials[0].maps[rl.MaterialMapIndex.NORMAL].texture
  shader := base.materials[0].shader

  rl.UnloadModel(base^)

  base^ = rl.LoadModel("res/base.glb")

  base.materials[0].maps[rl.MaterialMapIndex.ALBEDO].texture = albedo
  base.materials[0].maps[rl.MaterialMapIndex.NORMAL].texture = normal
  base.materials[0].shader = shader
}

main :: proc() {
  rl.SetConfigFlags(rl.ConfigFlags{.MSAA_4X_HINT})
  rl.InitWindow(1500, 900, "Planet creation tool")
  rl.SetTargetFPS(60)

  rl.DisableCursor()

  camera: rl.Camera3D
  camera.position = {0, 0, -10}
  camera.target = {0, 0, 0}
  camera.up = {0, 1, 0.001}
  camera.fovy = 65
  camera.projection = .PERSPECTIVE

  rl.GuiLoadStyle("res/dark.rgs")

  sekuya_font: rl.Font = rl.LoadFont("res/Sekuya-Regular.ttf")
  sekuya_font.baseSize = 30
  rl.GuiSetFont(sekuya_font)

  base: rl.Model = rl.LoadModel("res/base.glb")

  dirt_img: rl.Image = rl.LoadImage("res/stone.png")
  dirt_tex: rl.Texture2D = rl.LoadTextureFromImage(dirt_img)

  dirtnormal_img: rl.Image = rl.LoadImage("res/grass.png")
  dirtnormal_tex: rl.Texture2D = rl.LoadTextureFromImage(dirtnormal_img)

  shader: rl.Shader = rl.LoadShader("res/shaders/planet.vs", "res/shaders/planet.fs")
  base.materials[0].maps[rl.MaterialMapIndex.NORMAL].texture = dirtnormal_tex
  base.materials[0].maps[rl.MaterialMapIndex.ALBEDO].texture = dirt_tex
  base.materials[0].shader = shader

  color_loc := rl.GetShaderLocation(shader, "color")
  color_weight_loc := rl.GetShaderLocation(shader, "color_weight")
  water_color_loc := rl.GetShaderLocation(shader, "water_color")

  grass_texture_loc := rl.GetShaderLocation(shader, "texture1")
  fmt.printf("GRASS TEXTURE SHADER LOCATION %i\n", grass_texture_loc)
  rl.SetShaderValueTexture(shader, grass_texture_loc, dirtnormal_tex)

  regenerate_planet(&base)
  for !rl.WindowShouldClose() {
    dt: f32 = rl.GetFrameTime()
    mouse_pos: rl.Vector2 = rl.GetMousePosition()
    if !mouse_enabled {
      update_camera(&camera, dt)
    }

    if rl.IsMouseButtonReleased(.LEFT) {
      mouse_enabled = !mouse_enabled

      skip: bool = false
      if !mouse_enabled && mouse_pos.x < 400 {
        mouse_enabled = true
        skip = true
      }
      if !skip {
        if mouse_enabled {
          rl.EnableCursor()
        } else {
          rl.DisableCursor()
        }
      }
    }

    rl.BeginDrawing()
    rl.ClearBackground({0, 0, 0, 255})

    rl.BeginMode3D(camera)

    rl.DrawModel(base, {0, 0, 0}, 1, {255, 255, 255, 255})

    rl.EndMode3D()


    if rl.GuiButton({10, 10, 200, 50}, "Randomize") || rl.IsKeyPressed(.SPACE) {
      regenerate_planet(&base)
    }

    rl.GuiSlider({60, 70, 300, 20}, "Noise scale x", rl.TextFormat("%0.3f", noise_sample_scale_x), &noise_sample_scale_x, 0.01, 1)
    rl.GuiSlider({60, 100, 300, 20}, "Noise scale y", rl.TextFormat("%0.3f", noise_sample_scale_y), &noise_sample_scale_y, 0.01, 1)

    if rl.GuiButton({10, 130, 200, 50}, "Reset") {
      reload_model(&base)
    }

    rl.GuiColorPicker({10, 200, 300, 100}, "Primary color", &color) 
    rl.GuiSlider({60, 320, 300, 20}, "Primary color weight", rl.TextFormat("%0.3f", color_weight), &color_weight, 0, 1)

    colorV: rl.Vector4 = {f32(color.r)/255, f32(color.g)/255, f32(color.b)/255, 1}
    rl.SetShaderValue(shader, color_loc, &colorV, .VEC4)
    rl.SetShaderValue(shader, color_weight_loc, &color_weight, .FLOAT)

    rl.GuiCheckBox({60, 360, 100, 20}, "Oceans", &oceans)

    rl.GuiColorPicker({10, 400, 300, 100}, "Primary color", &water_color) 
    water_colorV: rl.Vector4 = {f32(water_color.r)/255, f32(water_color.g)/255, f32(water_color.b)/255, 1}
    rl.SetShaderValue(shader, water_color_loc, &water_colorV, .VEC4)
    
    rl.EndDrawing()
  }

  rl.UnloadImage(dirt_img)
  rl.UnloadTexture(dirt_tex)
  rl.UnloadImage(dirtnormal_img)
  rl.UnloadTexture(dirtnormal_tex)
  rl.UnloadShader(shader)
  rl.UnloadFont(sekuya_font)

  rl.UnloadModel(base)
  rl.CloseWindow()
}
