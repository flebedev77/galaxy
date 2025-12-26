package planet
import rl "vendor:raylib"

render_planet :: proc(planet: ^PlanetModel, pos := rl.Vector3{0, 0, 0}) {
  shader := planet.model.materials[0].shader
  rl.SetShaderValue(shader, planet.shader_locs.sea_level, &planet.settings.sea_level, .FLOAT)
  rl.SetShaderValue(shader, planet.shader_locs.snow_factor, &planet.settings.snow_factor, .FLOAT)
  rl.SetShaderValue(shader, planet.shader_locs.ao_intensity, &planet.settings.ao_intensity, .FLOAT)
  rl.SetShaderValue(shader, planet.shader_locs.noise_intensity, &planet.settings.noise_intensity, .FLOAT)
  rl.SetShaderValue(shader, planet.shader_locs.ao_darkness, &planet.settings.ao_darkness, .FLOAT)
  rl.SetShaderValue(shader, planet.shader_locs.ambient, &planet.shader_locs.ambient, .FLOAT)
  rl.SetShaderValue(shader, planet.shader_locs.shore_margin, &planet.settings.shore_margin, .FLOAT)
  rl.SetShaderValue(shader, planet.shader_locs.color_weight, &planet.settings.ao_weight, .FLOAT)
  c: rl.Vector4 = {f32(planet.settings.snow_color.r)/255, f32(planet.settings.snow_color.g)/255, f32(planet.settings.snow_color.b)/255, 1.0}
  rl.SetShaderValue(shader, planet.shader_locs.color, &c, .VEC4)
  wc: rl.Vector4 = {f32(planet.settings.water_color.r)/255, f32(planet.settings.water_color.g)/255, f32(planet.settings.water_color.b)/255, 1.0}
  rl.SetShaderValue(shader, planet.shader_locs.water_color, &wc, .VEC4)
  rl.DrawModel(planet.model, pos, 1, {255, 255, 255, 255})
}
