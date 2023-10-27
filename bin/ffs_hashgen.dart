import 'dart:convert';
import 'dart:io';
import 'dart:core';

import 'folder.dart';
import 'package:path/path.dart' as p;

Directory workingDir = Directory('FFS Hashgen');

void main(List<String> arguments) async {
  if (arguments.contains('/?') ||
      arguments.contains('--help') ||
      arguments.contains('/help')) {
    print('''
FFS Hashgen
by RedyAu in 2023
using Dart

Usage:
  ffs_hashgen [options]

Options:
  /?  Show this help
  /s  Wait for user input after finishing (keep window open)
  /g  Only generate json, then exit''');

    exit(0);
  }
  try {
    print('  === FFS Hashgen ===\nBy RedyAu (2023)\n\n');
    DateTime start = DateTime.now();

    if (!arguments.contains('/g')) {
      //! 0
      workingDir.createSync(recursive: true);
      if (!workingDir
          .listSync()
          .any((element) => p.extension(element.path) == '.ffs_batch')) {
        print(
            'No .ffs_batch file found!\nPut a copy of your desired batch file in "${p.absolute(workingDir.path)}".\nFFS Hashgen will modify it with the computed filter list and then launch FFS.\nMake sure this script is in the top level of the left-side FFS folder.');
        stdin.readLineSync();
        exit(1);
      }
    }

    //! 1
    File last = File(p.join(workingDir.path, 'last.json'));
    Folder? lastFolder;
    if (!arguments.contains('/g')) {
      try {
        print('1. Reading last.json...');
        DateTime now = DateTime.now();
        lastFolder = Folder.fromJson(json.decode(last.readAsStringSync()));
        print('  Done in ${DateTime.now().difference(now)}');
      } catch (_) {
        print('last.json not found or corrupted, syncing all files.');
      }
    }

    //! 2
    print('\n-------\n\n2. Calculating hashes for current folder...');
    Folder currentFolder = await getFolder(Directory('.'), root: true);
    print('  Writing json...');
    last.createSync(recursive: true);
    last.writeAsStringSync(currentFolder.toJson().toString());

    /*
  Pseudocode

  3.
  Go trough current root recursively:
  Find same path in lastFolder, if exists and hash is same, add to skipSync
  
  4.
  Consolidate skipSync:
  Remove all folders that are subfolders of other folders in skipSync
  */

    if (arguments.contains('/g')) exit(0);

    //! 3
    List<Directory> skipSync = [
      workingDir,
    ];

    void checkFolder(Folder current, Folder? last) {
      if (last == null) {
        return;
      }
      if (current.hash == last.hash &&
          current.directory.path == last.directory.path) {
        skipSync.add(current.directory);
      }
      for (var folder in current.subFolders) {
        try {
          var matchingFromLast = last.subFolders.firstWhere(
              (element) => element.directory.path == folder.directory.path);
          checkFolder(folder, matchingFromLast);
        } catch (_) {}
      }
    }

    try {
      print('\n-------\n\n3. Comparing current folder to last folder...');
      DateTime now = DateTime.now();
      checkFolder(currentFolder, lastFolder);
      print(
          '  Done in ${DateTime.now().difference(now)}. ${skipSync.length} folders to skip (with duplicates).');
    } catch (_) {
      print('Comparing failed, syncing all files.');
    }

    //! 4
    print('\n-------\n\n4. Removing paths covered by parent path...');
    DateTime now = DateTime.now();

    int i = 0;
    while (i < skipSync.length) {
      skipSync.removeWhere((element) =>
          element.path.startsWith(skipSync[i].path) &&
          element.path != skipSync[i].path);
      i++;
    }
    print('  Done in ${DateTime.now().difference(now)}\n\n');

    //! 5
    print('\n-------\n\n5. Creating modified batch file...');

    skipSync = skipSync.map((e) => Directory(p.normalize(e.path))).toList();

    print('Skip sync for: ${skipSync.length} folders.');
    File skipList = File(p.join(workingDir.path, 'skipList.txt'));
    skipList.createSync(recursive: true);
    skipList.writeAsStringSync(skipSync.map((e) => e.path).join('\n'));

    File batchFile = workingDir
        .listSync()
        .whereType<File>()
        .firstWhere((element) => element.path.endsWith('ffs_batch'));

    String batch = batchFile.readAsStringSync();
    batch = batch.replaceAllMapped(
        RegExp(r'(?<=<Exclude>).*(?=<\/Exclude>)', dotAll: true), (match) {
      String result = '\n';
      result += skipSync
          .map((e) => '            <Item By="ffs_hashgen">${e.path}</Item>')
          .join('\n');
      result += match[0]!;
      return result;
    });
    File newBatchFile =
        File('${p.withoutExtension(batchFile.path)}_filtered.ffs_batch');
    newBatchFile.createSync(recursive: true);
    newBatchFile.writeAsStringSync(batch);

    //! 6
    print('\n-------\n\n6. Launching FFS...');
    Process.start(
        r'C:\Program Files\FreeFileSync\FreeFileSync.exe', [newBatchFile.path]);

    print('\n\n-------\nFinished in ${DateTime.now().difference(start)}');
    if (arguments.contains('/s')) {
      // wait for enter
      stdin.readLineSync();
    }
  } catch (e, s) {
    print('An error occured: $e\n$s');
    stdin.readLineSync();
  }
}
