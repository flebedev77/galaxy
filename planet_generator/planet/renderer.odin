package planet
import rl "vendor:raylib"

render_planet :: proc(planet: ^PlanetModel) {
  shader := planet.model.materials[0].shader
  rl.SetShaderValue(shader, planet.shader_locs.sea_level, &planet.settings.sea_level, .FLOAT)
  rl.SetShaderValue(shader, planet.shader_locs.snow_factor, &planet.settings.snow_factor, .FLOAT)
  rl.SetShaderValue(shader, planet.shader_locs.ao_intensity, &planet.settings.ao_intensity, .FLOAT)
  rl.SetShaderValue(shader, planet.shader_locs.noise_intensity, &planet.settings.noise_intensity, .FLOAT)
  rl.SetShaderValue(shader, planet.shader_locs.ao_darkness, &planet.settings.ao_darkness, .FLOAT)
  rl.SetShaderValue(shader, planet.shader_locs.ambient, &planet.shader_locs.ambient, .FLOAT)
  rl.SetShaderValue(shader, planet.shader_locs.shore_margin, &planet.settings.shore_margin, .FLOAT)
  rl.DrawModel(planet.model, {0, 0, 0}, 1, {255, 255, 255, 255})
}
