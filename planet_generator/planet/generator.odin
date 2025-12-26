package planet
import "core:fmt"
import "core:math"
import "core:strconv"
import noise "core:math/noise"
import ini "core:encoding/ini"
import rl "vendor:raylib"

PlanetModel :: struct {
  settings: PlanetSettings,
  shader_locs: PlanetShaderLocations,
  model: rl.Model,
}

PlanetShaderLocations :: struct {
  sea_level: i32,
  shore_margin: i32,
  snow_factor: i32,
  ao_intensity: i32,
  ao_darkness: i32,
  noise_intensity: i32,
  ambient: i32,
  color: i32,
  color_weight: i32,
  water_color: i32
}

PlanetSettings :: struct {
  noise_sample_scale_x: f32,
  noise_sample_scale_y: f32,
  total_amplitude: f32,
  sea_level: f32,
  has_oceans: bool,
  noise_frequency: f32,
  noise_intensity: f32,
  snow_factor: f32,
  ao_intensity: f32,
  ao_darkness: f32,
  ao_weight: f32,
  ambient: f32,
  shore_margin: f32,
  seed_a: f32,
  seed_b: f32,
  snow_color: rl.Color,
  water_color: rl.Color,
}

regenerate_planet :: proc(model: ^PlanetModel) {
  reload_model(model)
  fmt.printfln("ambient %d", model.shader_locs.ao_darkness)
  fmt.printf("Number of meshes %i \n", model.model.meshCount)
  if model.model.meshCount < 1 {
    fmt.println("ERROR modifying a model with no mesh")
    return
  }

  mesh: rl.Mesh = model.model.meshes[0]
  settings := model.settings

  for i in 0..<mesh.vertexCount {
    x: f32 = mesh.vertices[i*3]
    y: f32 = mesh.vertices[i*3+1]
    z: f32 = mesh.vertices[i*3+2]

    leng: f32 = rl.Vector3Length({x, y, z})
    norm: rl.Vector3 = {x, y, z} / leng

    // theta: f32 = math.atan2(norm.y, norm.x)
    //
    // phi: f32 = math.acos(norm.z / leng)
    //
    // theta = theta * noise_sample_scale_x
    // phi = phi * noise_sample_scale_y

    scl: f64 = 0.5
    scl_det: f64 = 4

    mag_a: f32 = 0.8
    mag_b: f32 = 0.09
    noise_sample: noise.Vec3 = noise.Vec3{
      f64(norm.x * settings.noise_sample_scale_x),
      f64(norm.y * settings.noise_sample_scale_x),
      f64(norm.z * settings.noise_sample_scale_x)
    }
    disp: f32 = noise.noise_3d_improve_xy(i64(settings.seed_a), noise_sample * scl) * mag_a
    disp += noise.noise_3d_improve_xy(i64(settings.seed_b), noise_sample * scl_det * f64(settings.noise_sample_scale_y)) * mag_b
    mag_a += settings.total_amplitude
    normalized_disp := f32(math.abs(disp / (mag_a + mag_b)))

    mesh.texcoords2[i*2] = normalized_disp
    mesh.texcoords2[i*2+1] = noise.noise_3d_improve_xy(300, noise_sample*f64(settings.noise_frequency))

    if normalized_disp < settings.sea_level && settings.has_oceans {
      normalized_disp = settings.sea_level
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

reload_model :: proc(base: ^PlanetModel) -> PlanetModel {
  if base.model.materialCount != 0 {
    if rl.IsTextureValid(base.model.materials[0].maps[rl.MaterialMapIndex.ALBEDO].texture) {
      rl.UnloadTexture(base.model.materials[0].maps[rl.MaterialMapIndex.ALBEDO].texture)
    }

    if rl.IsTextureValid(base.model.materials[0].maps[rl.MaterialMapIndex.NORMAL].texture) {
      rl.UnloadTexture(base.model.materials[0].maps[rl.MaterialMapIndex.NORMAL].texture)
    }

    if rl.IsShaderValid(base.model.materials[0].shader) {
      rl.UnloadShader(base.model.materials[0].shader)
    }
  }
  if rl.IsModelValid(base.model) {
    rl.UnloadModel(base.model)
  }

  base.model = rl.LoadModel("res/base.glb")

  alb_img := rl.LoadImage("res/stone.png")
  nor_img := rl.LoadImage("res/grass.png")
  defer rl.UnloadImage(alb_img)
  defer rl.UnloadImage(nor_img)

  base.model.materials[0].maps[rl.MaterialMapIndex.ALBEDO].texture = rl.LoadTextureFromImage(alb_img)
  base.model.materials[0].maps[rl.MaterialMapIndex.NORMAL].texture = rl.LoadTextureFromImage(nor_img)

  base.model.materials[0].shader = rl.LoadShader("res/shaders/planet.vs", "res/shaders/planet.fs") 
  base.model.materials[0].shader.locs[rl.ShaderLocationIndex.MAP_NORMAL] =
    rl.GetShaderLocation(base.model.materials[0].shader, "normalMap")

  locs := PlanetShaderLocations {
    sea_level = rl.GetShaderLocation(base.model.materials[0].shader, "sea_level"),
    shore_margin = rl.GetShaderLocation(base.model.materials[0].shader, "shore_margin"),
    snow_factor = rl.GetShaderLocation(base.model.materials[0].shader, "snow_factor"),

    ao_intensity = rl.GetShaderLocation(base.model.materials[0].shader, "ao_intensity"),
    ao_darkness = rl.GetShaderLocation(base.model.materials[0].shader, "ao_darkness"),
    noise_intensity = rl.GetShaderLocation(base.model.materials[0].shader, "noise_intensity"),

    ambient = rl.GetShaderLocation(base.model.materials[0].shader, "ambient"),

    color = rl.GetShaderLocation(base.model.materials[0].shader, "color"),
    color_weight = rl.GetShaderLocation(base.model.materials[0].shader, "color_weight"),
    water_color = rl.GetShaderLocation(base.model.materials[0].shader, "water_color"),
  }

  base.shader_locs = locs

  return PlanetModel {
    base.settings,
    locs,
    base.model
  }
}

unload_planet :: proc(planet: PlanetModel) {
  rl.UnloadTexture(planet.model.materials[0].maps[rl.MaterialMapIndex.ALBEDO].texture)
  rl.UnloadTexture(planet.model.materials[0].maps[rl.MaterialMapIndex.NORMAL].texture)
  rl.UnloadShader(planet.model.materials[0].shader)
  rl.UnloadModel(planet.model)
}


settings_from_ini :: proc(filepath: string) -> PlanetSettings {
  ini_file, err, ok := ini.load_map_from_path(filepath, context.allocator)

  out := PlanetSettings{}
  out.has_oceans = true
  
  for key, value in ini_file {
    switch key {
      case "Settings":
        for k, v in value {
          // fmt.printfln("%s %s", k, v)
          parsed_value, ok := strconv.parse_f32(v)
          if !ok { fmt.panicf("ERROR parsing ini %s %s:%s", filepath, key, k) }
          switch k {
          case "noise_sample_scale_y": out.noise_sample_scale_y = parsed_value; break
          case "total_amplitude": out.total_amplitude = parsed_value; break
          case "ao_darkness": out.ao_darkness = parsed_value; break
          case "sea_level": out.sea_level = parsed_value; break
          case "snow_factor": out.snow_factor = parsed_value; break
          case "noise_sample_scale_x": out.noise_sample_scale_x = parsed_value; break
          case "ao_intensity": out.ao_intensity = parsed_value; break
          case "color_weight": out.ao_weight = parsed_value; break
          case "shore_margin": out.shore_margin = parsed_value; break
          case "ambient": out.ambient = parsed_value; break
          case "noise_intensity": out.noise_intensity = parsed_value; break
          }
        }
        break
      case "SnowColor":
        for k, v in value {
          parsed_value, ok := strconv.parse_int(v)
          if !ok { fmt.panicf("ERROR parsing ini %s %s", filepath, key) }
          if k == "r" { out.snow_color.r = u8(parsed_value) }
          else if k == "g" { out.snow_color.g = u8(parsed_value) }
          else if k == "b" { out.snow_color.b = u8(parsed_value) }
        }
        break

      case "WaterColor":
        for k, v in value {
          parsed_value, ok := strconv.parse_int(v)
          if !ok { fmt.panicf("ERROR parsing ini %s %s", filepath, key) }
          if k == "r" { out.water_color.r = u8(parsed_value) }
          else if k == "g" { out.water_color.g = u8(parsed_value) }
          else if k == "b" { out.water_color.b = u8(parsed_value) }
        }
        break
    }
  }

  return out
}
