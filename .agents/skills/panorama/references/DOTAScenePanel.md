# Scene panels

Рисовать 3D-контент в UI двумя типами панелей:

```xml
<DOTAScenePanel unit="npc_unit_name" />
<DOTAScenePanel map="scenes/map_name" />
<DOTAParticleScenePanel particleName="particles/path/name.vpcf" />
```

## DOTAScenePanel

| Атрибут | Тип | Назначение |
| --- | --- | --- |
| `camera` | string | `targetname` сущности `point_camera` внутри сцены |
| `environment` | string | Окружение из `portraits.txt`; без значения используется `default` |
| `light` | string | `targetname` источника света внутри сцены |
| `map` | string | Путь к `.vmap` относительно папки `maps` |
| `particleonly` | bool | Рисовать только частицы, без моделей и геометрии |
| `unit` | string | Имя юнита или героя из KV |

## DOTAParticleScenePanel

| Атрибут | Тип | Назначение |
| --- | --- | --- |
| `cameraOrigin` | vector | Позиция камеры |
| `fov` | float | Поле зрения |
| `lookAt` | vector | Точка, на которую смотрит камера |
| `particleName` | string | Путь к `.vpcf` |
