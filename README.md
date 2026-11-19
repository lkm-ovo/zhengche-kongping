# 整车空瓶

一款第一人称瓶子回收游戏。从手工刮标、清洗、消毒、沥干和出售开始，用回收收入升级刀具，逐步接入自动生产线。

## 运行

1. 用 Godot `4.7.2` 打开 `game/project.godot`，按 `F5` 运行项目。
2. Windows 下也可以将 `Godot_v4.7.2-stable_win64.exe` 放到 `build/engine/`，双击 `运行整车空瓶.cmd`。

- `WASD` 移动，`E` 交互或取瓶，`Tab` 打开站务。
- 刮标时按住右键向下拖动，按住左键转瓶。换刀后会从下一瓶开始使用新刀。
- `R` 放回手上的瓶子，`Esc` 离开工作台或释放鼠标。

## 测试与导出

在仓库根目录运行下列命令（将 `godot` 换成本机 Godot 可执行文件的路径）。测试不会读取或写入游戏存档。

```sh
godot --headless --path game --editor --import
godot --headless --fixed-fps 60 --path game --script res://verify/playtest.gd -- --yard-playtest
```

如需导出 Windows 版，先在 Godot 中安装与编辑器同版本的导出模板，再使用项目内的 `Windows` 预设导出。仓库不包含 Godot 本体、导出模板、构建产物或本地存档。手部素材来源见 [素材说明](game/assets/worker_hands.SOURCE.md)。
