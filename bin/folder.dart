import 'dart:io';

class Folder {
  int hash;
  Directory directory;
  List<Folder> subFolders;

  Folder(this.hash, this.directory, this.subFolders);

  Map toJson() {
    return {
      '"$hash"': {
        '"path"': '"${directory.path.replaceAll(r'\', '/')}"',
        '"subFolders"': subFolders.map((e) => e.toJson()).toList(),
      }
    };
  }

  factory Folder.fromJson(Map json) {
    return Folder(
      int.parse(json.keys.first.replaceAll('"', '')),
      Directory(json.values.first['path'].replaceAll('/', r'\')),
      json.values.first['subFolders']
          .map<Folder>((e) => Folder.fromJson(e))
          .toList(),
    );
  }
}

int files = 0;
int directories = 0;
int fileErrors = 0;
int directoryErrors = 0;

getFolder(Directory dir, {bool root = false}) async {
  DateTime now = DateTime.now();

  List<Folder> subFolders = [];
  subFolders.clear(); // sync list is faster, but throws errors
  List<FileSystemEntity> entities;
  try {
    entities = dir.listSync();
  } catch (_) {
    entities = await dir
        .list()
        .handleError(
          (_) => {
            directoryErrors++,
          },
        )
        .toList();
  }

  int localFileErrors = 0;
  List<int> toHashOfFiles = [];

  for (var entity in entities) {
    if (entity is File) {
      try {
        toHashOfFiles.add(entity.path.hashCode);
        toHashOfFiles.add(entity.lengthSync());
        toHashOfFiles.add(entity.lastModifiedSync().millisecondsSinceEpoch);
        files++;
        if (files % 50000 == 0) print('Files: $files');
      } catch (_) {
        fileErrors++;
        localFileErrors++;
      }
    } else if (entity is Directory) {
      subFolders.add(await getFolder(entity));
      directories++;
      if (directories % 5000 == 0) print('Directories: $directories');
    }
    toHashOfFiles.add(localFileErrors);
  }
  List<int> toHashOfSelf;
  try {
    var stat = dir.statSync();
    toHashOfSelf = [
      dir.path.hashCode,
      stat.size,
      stat.modified.millisecondsSinceEpoch,
    ];
  } catch (_) {
    toHashOfSelf = [
      dir.path.hashCode,
    ];
  }
  List<int> hashList = [
    ...toHashOfSelf,
    ...toHashOfFiles,
    ...subFolders.map((e) => e.hash).toList()
  ];
  int hash =
      hashList.fold(0, (previousValue, element) => previousValue ^ element);

  if (root) {
    // Print elapsed time and stats
    print('''

Files: $files
Directories: $directories
File errors: $fileErrors
Directory errors: $directoryErrors

Done in ${DateTime.now().difference(now)}''');
  }

  return Folder(hash, dir, subFolders);
}
