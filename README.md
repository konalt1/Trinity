## Запуск на Windows (примерный)

### Создание директории проекта

```bash
$ mkdir Trinity
$ cd Trinity
```

### Создание символических ссылок (Symlinks)

1. Создайте необходимые папки в папке Steam:

```bash
$ mkdir "PATH_TO_STEAM\steamapps\common\dota 2 beta\game\dota_addons\trinity"
$ mkdir "PATH_TO_STEAM\steamapps\common\dota 2 beta\content\dota_addons\trinity"
```

2. Создайте символические ссылки на эти папки:

```bash
$ mklink /j Game "PATH_TO_STEAM\steamapps\common\dota 2 beta\game\dota_addons\trinity"
$ mklink /j Content "PATH_TO_STEAM\steamapps\common\dota 2 beta\content\dota_addons\trinity"
```

### Импорт из GitHub репозитория

1. Инициализируйте репозиторий и настройте поддержку символических ссылок:

```bash
$ git init
$ git config core.symlinks true
```

2. Добавьте удалённый репозиторий и выполните сброс:

```bash
$ git remote add origin git@github.com:konalt1/Trinity.git
$ git reset --hard origin/master
```
