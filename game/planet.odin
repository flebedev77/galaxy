package game
import rl "vendor:raylib"
import planet_renderer "../planet_generator/planet"

Planet :: struct {
  is_static: bool,
  position: rl.Vector3,
  velocity: rl.Vector3,
  radius: f32,
  color: rl.Color,
  mass: f32,
  name: cstring,
  path_prediction_enabled: bool,
  model: planet_renderer.PlanetModel,
  has_model: bool
}

planet_init :: proc(planet: ^Planet, planet_settings_path: string) {
  planet.has_model = true
  planet.model.settings = planet_renderer.settings_from_ini(planet_settings_path)
  planet_renderer.regenerate_planet(&planet.model)
  scl : f32 = planet.radius
  planet.model.model.transform = rl.MatrixScale(scl, scl, scl)
}

planet_draw :: proc(planet: ^Planet) {
  if !planet.has_model {
    rl.DrawSphereWires(planet.position, planet.radius, 5, 5, planet.color)
  } else {
    planet_renderer.render_planet(&planet.model)
  }
}

planet_unload :: proc(planet: Planet) {
  planet_renderer.unload_planet(planet.model)
}
