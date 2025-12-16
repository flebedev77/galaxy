package planet_generator;
import "core:fmt";
import "core:math";
import "core:mem";
import rl "vendor:raylib";
import rlgl "vendor:raylib/rlgl";
import rand "core:math/rand";
import noise "core:math/noise";

camera_zoom_factor: f32 = 10;

noise_sample_scale_x: f32 = 0.01;
noise_sample_scale_y: f32 = 1;

update_camera :: proc(camera: ^rl.Camera, dt: f32) {
    rl.UpdateCamera(camera, .THIRD_PERSON);
    scroll: f32 = -rl.GetMouseWheelMove() * dt * 60 * 0.05;
    camera_dir: rl.Vector3 = camera.position;
    camera_len: f32 = rl.Vector3Length(camera_dir);
    normalized_camera_dir: rl.Vector3 = camera_dir / camera_len;
    zoom_factor: f32 = 1 + (camera_len / camera_zoom_factor);
    camera.position = normalized_camera_dir * (camera_len + scroll * zoom_factor);
}

mouse_enabled: bool = false;

regenerate_planet :: proc(model: ^rl.Model) {
  fmt.printf("Number of meshes %i \n", model.meshCount);
  if model.meshCount < 1 {
    fmt.println("ERROR modifying a model with no mesh");
    return;
  }

  mesh: rl.Mesh = model.meshes[0];

  for i in 0..<mesh.vertexCount {
    x: f32 = mesh.vertices[i*3];
    y: f32 = mesh.vertices[i*3+1];
    z: f32 = mesh.vertices[i*3+2];

    leng: f32 = rl.Vector3Length({x, y, z});
    norm: rl.Vector3 = {x, y, z} / leng;

    theta: f32 = math.atan2(norm.y, norm.x);

    phi: f32 = math.acos(norm.z / leng);

    theta = f32(i) * noise_sample_scale_x;
    phi = theta * noise_sample_scale_y;

    scl: f64 = 0.6;
    scl_det: f64 = 1.5;
    noise_sample: noise.Vec2 = noise.Vec2{f64(phi), f64(theta)};
    disp: f32 = noise.noise_2d(100, noise_sample * scl) * 0.4;
    disp += noise.noise_2d(200, noise_sample * scl_det) * 0.35;

    if disp > 0 {
      disp = 0;
    }

    leng += disp

    final: rl.Vector3 = norm * leng;
    mesh.vertices[i*3]   = final.x;
    mesh.vertices[i*3+1] = final.y;
    mesh.vertices[i*3+2] = final.z;

    mesh.texcoords2[i*2] = leng;
    mesh.texcoords2[i*2+1] = 0; // Can encode something useful here aswell
  }

  rl.UpdateMeshBuffer(mesh, 0, mesh.vertices, mesh.vertexCount * size_of(f32) * 3, 0);
  rl.UpdateMeshBuffer(mesh, 5, mesh.texcoords2, mesh.vertexCount * size_of(f32) * 2, 0);
}

reload_model :: proc(base: ^rl.Model) {
  albedo := base.materials[0].maps[rl.MaterialMapIndex.ALBEDO].texture;
  normal := base.materials[0].maps[rl.MaterialMapIndex.NORMAL].texture;
  shader := base.materials[0].shader;

  rl.UnloadModel(base^);

  base^ = rl.LoadModel("res/base.glb");

  base.materials[0].maps[rl.MaterialMapIndex.ALBEDO].texture = albedo;
  base.materials[0].maps[rl.MaterialMapIndex.NORMAL].texture = normal;
  base.materials[0].shader = shader;
}

main :: proc() {
  rl.InitWindow(1500, 900, "Planet creation tool");
  rl.SetTargetFPS(60);

  rl.DisableCursor();

  camera: rl.Camera3D;
  camera.position = {0, 0, -10};
  camera.target = {0, 0, 0};
  camera.up = {0, 1, 0.001};
  camera.fovy = 65;
  camera.projection = .PERSPECTIVE;

  rl.GuiLoadStyle("res/dark.rgs");

  sekuya_font: rl.Font = rl.LoadFont("res/Sekuya-Regular.ttf");
  sekuya_font.baseSize = 30;
  rl.GuiSetFont(sekuya_font);

  base: rl.Model = rl.LoadModel("res/base.glb");

  dirt_img: rl.Image = rl.LoadImage("res/dirt_albedo.png");
  dirt_tex: rl.Texture2D = rl.LoadTextureFromImage(dirt_img);

  dirtnormal_img: rl.Image = rl.LoadImage("res/dirt_normal.png");
  dirtnormal_tex: rl.Texture2D = rl.LoadTextureFromImage(dirtnormal_img);

  shader: rl.Shader = rl.LoadShader("res/shaders/planet.vs", "res/shaders/planet.fs");
  base.materials[0].maps[rl.MaterialMapIndex.NORMAL].texture = dirtnormal_tex;
  base.materials[0].maps[rl.MaterialMapIndex.ALBEDO].texture = dirt_tex;
  base.materials[0].shader = shader;

  regenerate_planet(&base);
  for !rl.WindowShouldClose() {
    dt: f32 = rl.GetFrameTime();
    mouse_pos: rl.Vector2 = rl.GetMousePosition();
    if !mouse_enabled {
      update_camera(&camera, dt);
    }

    if rl.IsMouseButtonReleased(.LEFT) {
      mouse_enabled = !mouse_enabled;
      if mouse_enabled {
        rl.EnableCursor();
      } else if mouse_pos.x > 310 && mouse_pos.y > 200 {
        rl.DisableCursor();
      }
    }

    rl.BeginDrawing();
    rl.ClearBackground({0, 0, 0, 255});

    rl.BeginMode3D(camera);
    rlgl.DisableBackfaceCulling();
    rlgl.DisableDepthMask();

    rl.DrawModel(base, {0, 0, 0}, 1, {255, 255, 255, 255});

    rl.EndMode3D();


    if rl.GuiButton({10, 10, 200, 50}, "Randomize") {
      regenerate_planet(&base);
    }

    rl.GuiSlider({60, 70, 300, 20}, "Noise scale x", rl.TextFormat("%0.3f", noise_sample_scale_x), &noise_sample_scale_x, 0.01, 1);
    rl.GuiSlider({60, 100, 300, 20}, "Noise scale y", rl.TextFormat("%0.3f", noise_sample_scale_y), &noise_sample_scale_y, 0.01, 1);

    if rl.GuiButton({10, 130, 200, 50}, "Reset") {
      reload_model(&base);
    }

    rl.EndDrawing();
  }

  rl.UnloadImage(dirt_img);
  rl.UnloadTexture(dirt_tex);
  rl.UnloadImage(dirtnormal_img);
  rl.UnloadTexture(dirtnormal_tex);
  rl.UnloadShader(shader);
  rl.UnloadFont(sekuya_font);

  rl.UnloadModel(base);
  rl.CloseWindow();
}
