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
  } else {
    planet_renderer.render_planet(&planet.model, planet.position)
  }
  rl.DrawSphereWires(planet.position, planet.radius, 5, 5, planet.color)
}

planet_update :: proc(planet: ^Planet, dt: f32) {
  if planet.is_static {
    return 
  }
  d: rl.Vector3 = planet.position - local_player.position
  l: f32 = rl.Vector3Length(d)

  if l == 0 || l < planet.radius {
    local_player.velocity = 0
    return
  }
  n: rl.Vector3 = d / l

  f: f32 = GRAVITATIONAL_CONSTANT * ((10000000 * planet.mass) / l)
  local_player.velocity += n * f * dt

  for &bullet in local_player.bullets {
    d = planet.position - bullet.position
    l = rl.Vector3Length(d)

    if l == 0 || l < planet.radius {
      // remove bullet
    }

    n = d / l
    f: f32 = GRAVITATIONAL_CONSTANT * ((10000 * planet.mass) / l)
    bullet.velocity += f * n * dt
  }
}

planet_unload :: proc(planet: Planet) {
  planet_renderer.unload_planet(planet.model)
}
