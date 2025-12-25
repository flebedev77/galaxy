package planet_generator
import "core:fmt"
import "core:math"
import "core:strings"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"
import noise "core:math/noise"
import ini "core:encoding/ini"
import "core:io"
import "core:os"

camera_zoom_factor: f32 = 350

noise_sample_scale_x: f32 = 1
noise_sample_scale_y: f32 = 1

color: rl.Color = {0, 0, 0, 255}
water_color: rl.Color = {0, 0, 210, 255}
color_weight: f32 = 0.176

sea_level: f32 = 0.3
snow_factor: f32 = 0.5

oceans: bool = true

ao_intensity: f32 = 0
ao_darkness: f32 = 0

noise_intensity: f32 = 0
noise_frequency: f32 = 1

ambient: f32 = 0

shore_margin: f32 = 0.1

total_amplitude: f32 = 1

export_path: string : "./res/earth"
export_path_cstr: cstring
WINDOW_WIDTH :: 1500
WINDOW_HEIGHT :: 900

update_camera :: proc(camera: ^rl.Camera, dt: f32) {
    rl.UpdateCamera(camera, .THIRD_PERSON)
    scroll: f32 = -rl.GetMouseWheelMove() * dt * 60 * 0.01
    camera_dir: rl.Vector3 = camera.position
    camera_len: f32 = rl.Vector3Length(camera_dir)
    normalized_camera_dir: rl.Vector3 = camera_dir / camera_len
    zoom_factor: f32 = 1 + (camera_len / camera_zoom_factor) * 0.01
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

    scl: f64 = 0.5
    scl_det: f64 = 4

    mag_a: f32 = 0.8
    mag_b: f32 = 0.09
    noise_sample: noise.Vec3 = noise.Vec3{f64(norm.x * noise_sample_scale_x), f64(norm.y * noise_sample_scale_x), f64(norm.z * noise_sample_scale_x)}
    disp: f32 = noise.noise_3d_improve_xy(100, noise_sample * scl) * mag_a
    disp += noise.noise_3d_improve_xy(200, noise_sample * scl_det * f64(noise_sample_scale_y)) * mag_b
    mag_a += total_amplitude
    normalized_disp := f32(math.abs(disp / (mag_a + mag_b)))

    mesh.texcoords2[i*2] = normalized_disp
    mesh.texcoords2[i*2+1] = noise.noise_3d_improve_xy(300, noise_sample*f64(noise_frequency))

    if normalized_disp < sea_level && oceans {
      normalized_disp = sea_level
    }

    leng += normalized_disp
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
  sb := strings.builder_make()
  strings.write_string(&sb, export_path)
  export_path_cstr = strings.to_cstring(&sb)

  rl.SetConfigFlags(rl.ConfigFlags{.MSAA_4X_HINT})
  rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Planet creation tool")
  rl.SetTargetFPS(60)

  rl.DisableCursor()

  camera: rl.Camera3D
  camera.position = {0, 0, -4}
  camera.target = {0, 0, 0}
  camera.up = {0, 1, 0.001}
  camera.fovy = 65
  camera.projection = .PERSPECTIVE

  skybox := rl.LoadModelFromMesh(rl.GenMeshSphere(100, 10, 10))
  skybox.materials[0].shader = rl.LoadShader("res/shaders/sky.vs", "res/shaders/sky.fs")
  skybox_time_loc := rl.GetShaderLocation(skybox.materials[0].shader, "time")

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
  shader.locs[rl.ShaderLocationIndex.MAP_NORMAL] = rl.GetShaderLocation(shader, "normalMap")

  sealevel_loc := rl.GetShaderLocation(shader, "sea_level")
  shore_margin_loc := rl.GetShaderLocation(shader, "shore_margin")
  snow_factor_loc := rl.GetShaderLocation(shader, "snow_factor")

  ao_intensity_loc := rl.GetShaderLocation(shader, "ao_intensity")
  ao_darkness_loc := rl.GetShaderLocation(shader, "ao_darkness")
  noise_intensity_loc := rl.GetShaderLocation(shader, "noise_intensity")

  ambient_loc := rl.GetShaderLocation(shader, "ambient");

  color_loc := rl.GetShaderLocation(shader, "color")
  color_weight_loc := rl.GetShaderLocation(shader, "color_weight")
  water_color_loc := rl.GetShaderLocation(shader, "water_color")

  regenerate_planet(&base)
  for !rl.WindowShouldClose() {
    dt: f32 = rl.GetFrameTime()
    gt: f32 = f32(rl.GetTime())
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

    rlgl.DisableDepthMask()
    rlgl.DisableBackfaceCulling()
    // rl.SetShaderValue(skybox.materials[0].shader, skybox_time_loc, &gt, rl.ShaderUniformDataType.FLOAT)
    rl.DrawModel(skybox, camera.position, 1, {255, 255, 255, 255})
    // rlgl.EnableBackfaceCulling()
    rlgl.EnableDepthMask()

    rl.SetShaderValue(shader, sealevel_loc, &sea_level, .FLOAT)
    rl.SetShaderValue(shader, snow_factor_loc, &snow_factor, .FLOAT)
    rl.SetShaderValue(shader, ao_intensity_loc, &ao_intensity, .FLOAT)
    rl.SetShaderValue(shader, noise_intensity_loc, &noise_intensity, .FLOAT)
    rl.SetShaderValue(shader, ao_darkness_loc, &ao_darkness, .FLOAT)
    rl.SetShaderValue(shader, ambient_loc, &ambient, .FLOAT)
    rl.SetShaderValue(shader, shore_margin_loc, &shore_margin, .FLOAT)
    rl.DrawModel(base, {0, 0, 0}, 1, {255, 255, 255, 255})

    rl.EndMode3D()


    if rl.GuiButton({10, 10, 200, 50}, "Randomize") || rl.IsKeyPressed(.SPACE) {
      regenerate_planet(&base)
    }

    rl.GuiSlider({60, 70, 300, 20}, "Noise scale x", rl.TextFormat("%0.3f", noise_sample_scale_x), &noise_sample_scale_x, 0.01, 3)
    rl.GuiSlider({60, 100, 300, 20}, "Noise scale y", rl.TextFormat("%0.3f", noise_sample_scale_y), &noise_sample_scale_y, 0.01, 5)

    if rl.GuiButton({10, 130, 200, 50}, "Reset") {
      reload_model(&base)
    }

    rl.GuiColorPicker({10, 200, 300, 100}, "Primary color", &color) 
    rl.GuiSlider({90, 320, 300, 20}, "Primary color weight", rl.TextFormat("%0.3f", color_weight), &color_weight, 0, 1)
    rl.GuiSlider({90, 550, 300, 10}, "SEA LVL", rl.TextFormat("%0.3f", sea_level), &sea_level, 0, 1)
    rl.GuiSlider({90, 550 + 15, 300, 10}, "SNOW FAC", rl.TextFormat("%0.3f", snow_factor), &snow_factor, 0, 1)
    rl.GuiSlider({90, 550 + 15 + 15, 300, 10}, "AO int", rl.TextFormat("%0.3f", ao_intensity), &ao_intensity, 0, 5)
    rl.GuiSlider({90, 550 + 15*3, 300, 10}, "AO drk", rl.TextFormat("%0.3f", ao_darkness), &ao_darkness, 0, 1)
    rl.GuiSlider({90, 550 + 15*4, 300, 10}, "NOI int", rl.TextFormat("%0.3f", noise_intensity), &noise_intensity, 0, 0.5)
    rl.GuiSlider({90, 550 + 15*5, 300, 10}, "NOI freq", rl.TextFormat("%0.3f", noise_frequency), &noise_frequency, 0, 5)
    rl.GuiSlider({90, 550 + 15*6, 300, 10}, "AMB", rl.TextFormat("%0.3f", ambient), &ambient, 0, 1)
    rl.GuiSlider({90, 550 + 15*7, 300, 10}, "SHORE MAR", rl.TextFormat("%0.3f", shore_margin), &shore_margin, 0, 1)
    rl.GuiSlider({90, 550 + 15*8, 300, 10}, "TOT AMP", rl.TextFormat("%0.3f", total_amplitude), &total_amplitude, 0, 5)

    colorV: rl.Vector4 = {f32(color.r)/255, f32(color.g)/255, f32(color.b)/255, 1}
    rl.SetShaderValue(shader, color_loc, &colorV, .VEC4)
    rl.SetShaderValue(shader, color_weight_loc, &color_weight, .FLOAT)

    rl.GuiCheckBox({60, 360, 100, 20}, "Oceans", &oceans)

    rl.GuiColorPicker({10, 400, 300, 100}, "Primary color", &water_color) 
    water_colorV: rl.Vector4 = {f32(water_color.r)/255, f32(water_color.g)/255, f32(water_color.b)/255, 1}
    rl.SetShaderValue(shader, water_color_loc, &water_colorV, .VEC4)

    rl.GuiTextBox({ WINDOW_WIDTH - 410, WINDOW_HEIGHT - 60 - 30, 400, 20 }, export_path_cstr, 16, false)
    if rl.GuiButton({ 10, WINDOW_HEIGHT - 60, 200, 50 }, "EXPORT") {
      // strings.builder_reset(&sb)
      // strings.write_string(&sb, export_path + ".obj")
      // strings.write_byte(&sb, 0)
      // cstr: cstring = strings.to_cstring(&sb)
      // fmt.printfln("EXPORT STRING %s", cstr)
      // if !rl.ExportMesh(base.meshes[0], cstr) {
      //   break 
      // }

      // if !export_model_glb(base.meshes[0], export_path + ".glb") {
      //   break
      // }
      // config: ini.Map
      // v: map[string]string
      // map_insert(&v, "hi", "world")
      // map_insert(&config, "Hi", v)
      //
      //
      //
      // ini.write_map()
    }
    
    rl.EndDrawing()
  }

  rl.UnloadImage(dirt_img)
  rl.UnloadTexture(dirt_tex)
  rl.UnloadImage(dirtnormal_img)
  rl.UnloadTexture(dirtnormal_tex)
  rl.UnloadShader(shader)
  rl.UnloadFont(sekuya_font)


  rl.UnloadShader(skybox.materials[0].shader);
  rl.UnloadModel(skybox)

  rl.UnloadModel(base)
  rl.CloseWindow()
}
