import os
import sys
import json
import argparse
from pathlib import Path

def process_scan(scan_folder_path: str, output_format: str = "obj"):
    """
    Обрабатывает сессию сканирования с iPhone 11 / 11 Pro:
    1. Загружает фото и transforms.json (6DoF позы камер)
    2. Выполняет реконструкцию поверхности
    3. Сохраняет готовую 3D модель (.obj / .usdz)
    """
    scan_dir = Path(scan_folder_path)
    if not scan_dir.exists():
        print(f"[!] Папка не найдена: {scan_dir}")
        return
        
    transforms_file = scan_dir / "transforms.json"
    if not transforms_file.exists():
        print(f"[!] transforms.json не найден в {scan_dir}")
        return
        
    with open(transforms_file, "r", encoding="utf-8") as f:
        meta = json.load(f)
        
    frames = meta.get("frames", [])
    print(f"[*] Найдено {len(frames)} ракурсов с 6DoF позами камеры.")
    print(f"[*] Фокусное расстояние: fl_x={meta.get('fl_x')}, fl_y={meta.get('fl_y')}")
    print(f"[*] Разрешение снимков: {meta.get('w')}x{meta.get('h')}")
    
    ply_file = scan_dir / "sparse_cloud.ply"
    out_model = scan_dir / f"model_output.{output_format}"
    
    print("\n--- Варианты создания 3D модели ---")
    print("1. 3D Gaussian Splatting (3DGS):")
    print("   Команда: gaussian-splatting --source_path", scan_dir)
    print("2. Nerfstudio (Splatfacto):")
    print("   Команда: ns-train splatfacto --data", scan_dir)
    print("3. Экспорт меша через Open3D / Poisson Reconstruction...")
    
    # Пытаемся запустить поверхностную реконструкцию через Open3D, если он установлен
    try:
        import open3d as o3d
        if ply_file.exists():
            print(f"[*] Загрузка облака точек {ply_file}...")
            pcd = o3d.io.read_point_cloud(str(ply_file))
            pcd.estimate_normals()
            
            print("[*] Вычисление полигональной сетки (Poisson Surface Reconstruction)...")
            mesh, densities = o3d.geometry.TriangleMesh.create_from_point_cloud_poisson(pcd, depth=8)
            
            o3d.io.write_triangle_mesh(str(out_model), mesh)
            print(f"[+] Успешно сохранена 3D модель: {out_model}")
            print(f"[+] Передайте {out_model.name} обратно на iPhone во вкладку «3D Объекты»!")
            return
    except ImportError:
        print("[i] Open3D не установлен. Установите: pip install open3d numpy")
        
    print(f"[+] Датасет готов к отправке в RealityCapture / Meshroom / Instant-NGP!")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Обработка 6DoF сканов с iPhone")
    parser.add_argument("folder", help="Путь к папке со сканом (например Scan_20261008_180000)")
    parser.add_argument("--format", default="obj", choices=["obj", "ply", "usdz"], help="Формат 3D модели")
    args = parser.parse_args()
    process_scan(args.folder, args.format)
