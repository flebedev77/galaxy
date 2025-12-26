package planet_generator
import "core:fmt"
import "core:math"
import "core:strings"
import "core:strconv"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"
import ini "core:encoding/ini"
import csv "core:encoding/csv"
import "core:io"
import "core:os"
import "core:mem"

import "planet"

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

export_ini :: proc() {
  fmt.printf("EXPORTING")
  config: ini.Map
  v: map[string]string
  water_color_map: map[string]string
  snow_color: map[string]string

  defer delete(config)
  defer delete(v)
  defer delete(water_color_map)
  defer delete(snow_color)

  map_insert(&v, "sea_level", float_to_string(sea_level))
  map_insert(&v, "snow_factor", float_to_string(snow_factor))
  map_insert(&v, "ao_intensity", float_to_string(ao_intensity))
  map_insert(&v, "noise_intensity", float_to_string(noise_intensity))
  map_insert(&v, "ao_darkness", float_to_string(ao_darkness))
  map_insert(&v, "ambient", float_to_string(ambient))
  map_insert(&v, "shore_margin", float_to_string(shore_margin))
  map_insert(&v, "color_weight", float_to_string(color_weight))
  map_insert(&v, "noise_sample_scale_x", float_to_string(noise_sample_scale_x))
  map_insert(&v, "noise_sample_scale_y", float_to_string(noise_sample_scale_y))
  map_insert(&v, "total_amplitude", float_to_string(total_amplitude))

  map_insert(&water_color_map, "r", u8str(water_color.r))
  map_insert(&water_color_map, "g", u8str(water_color.g))
  map_insert(&water_color_map, "b", u8str(water_color.b))

  map_insert(&snow_color, "r", u8str(color.r))
  map_insert(&snow_color, "g", u8str(color.g))
  map_insert(&snow_color, "b", u8str(color.b))

  map_insert(&config, "Settings", v)
  map_insert(&config, "WaterColor", water_color_map)
  map_insert(&config, "SnowColor", snow_color)

  out: string = ini.save_map_to_string(config, context.allocator)
  os.write_entire_file("./res/planet.ini", transmute([]u8)out[:])

  free_all(context.temp_allocator)
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

  sett: planet.PlanetSettings
  planet_obj := planet.PlanetModel {}
  package_settings(&planet_obj)
  planet.regenerate_planet(&planet_obj)

  for !rl.WindowShouldClose() {
    // if 1==1 {
    //   break
    // }
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
  
    package_settings(&planet_obj)
    planet.render_planet(&planet_obj)

    rl.EndMode3D()


    if rl.GuiButton({10, 10, 200, 50}, "Randomize") || rl.IsKeyPressed(.SPACE) {
      planet.regenerate_planet(&planet_obj)
    }

    rl.GuiSlider({60, 70, 300, 20}, "Noise scale x", rl.TextFormat("%0.3f", noise_sample_scale_x), &noise_sample_scale_x, 0.01, 3)
    rl.GuiSlider({60, 100, 300, 20}, "Noise scale y", rl.TextFormat("%0.3f", noise_sample_scale_y), &noise_sample_scale_y, 0.01, 5)

    if rl.GuiButton({10, 130, 200, 50}, "Reset") {
      planet.reload_model(&planet_obj)
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

    shader := planet_obj.model.materials[0].shader
    colorV: rl.Vector4 = {f32(color.r)/255, f32(color.g)/255, f32(color.b)/255, 1}
    rl.SetShaderValue(shader, planet_obj.shader_locs.color, &colorV, .VEC4)
    rl.SetShaderValue(shader, planet_obj.shader_locs.color_weight, &color_weight, .FLOAT)

    rl.GuiCheckBox({60, 360, 100, 20}, "Oceans", &oceans)

    rl.GuiColorPicker({10, 400, 300, 100}, "Primary color", &water_color) 
    water_colorV: rl.Vector4 = {f32(water_color.r)/255, f32(water_color.g)/255, f32(water_color.b)/255, 1}
    rl.SetShaderValue(shader, planet_obj.shader_locs.water_color, &water_colorV, .VEC4)


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
      export_ini()
    }
    
    rl.EndDrawing()
  }

  planet.unload_planet(planet_obj)
  rl.UnloadFont(sekuya_font)


  rl.UnloadShader(skybox.materials[0].shader);
  rl.UnloadModel(skybox)

  rl.CloseWindow()
}

float_to_string :: proc(val: f32, allocator := context.temp_allocator) -> string {
  buf, err := mem.alloc_bytes(100, mem.DEFAULT_ALIGNMENT, allocator)
  return strconv.write_float(buf[:], f64(val), 'f', 5, 64)
}
u8str :: proc(val: u8, allocator := context.temp_allocator) -> string {
  buf, err := mem.alloc_bytes(100, mem.DEFAULT_ALIGNMENT, allocator)
  return strconv.write_int(buf[:], i64(val), 10)
}

package_settings :: proc(set: ^planet.PlanetModel) {
  set.settings.noise_sample_scale_x = noise_sample_scale_x
  set.settings.noise_sample_scale_y = noise_sample_scale_y
  set.settings.total_amplitude = total_amplitude
  set.settings.sea_level = sea_level
  set.settings.has_oceans = oceans
  set.settings.noise_frequency = noise_frequency
  set.settings.noise_intensity = noise_intensity
  set.settings.snow_factor = snow_factor
  set.settings.ao_intensity = ao_intensity
  set.settings.ao_darkness = ao_darkness
  set.settings.ambient = ambient
  set.settings.shore_margin = shore_margin
}
