import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_treeview/flutter_treeview.dart';
import 'package:permission_handler/permission_handler.dart';

class FileTree extends StatefulWidget {
  final String path;
  final Function(FileSystemEntity file)? onSelectedChange;

  const FileTree({
    super.key,
    required this.path,
    this.onSelectedChange,
  });

  @override
  State<FileTree> createState() => _FileTreeState();
}

class _FileTreeState extends State<FileTree> {
  var treeViewController = TreeViewController();
  String? selectedNode;
  List<FileSystemEntity> fileList = [];

  @override
  void initState() {
    super.initState();

    requestPermission();
  }

  void requestPermission() async {
    await [
      Permission.storage,
      Permission.manageExternalStorage,
    ].request();

    readFileList();
  }

  void readFileList() {
    var dir = Directory(widget.path);

    if (!dir.existsSync()) {
      dir.createSync();
    }

    fileList = dir.listSync(recursive: true);
    selectedNode = null;
    buildFileTree();
  }

  void buildFileTree() async {
    List<Node> hierarchyNodes = [];

    for (var document in fileList) {
      String file = document.path.replaceFirst(widget.path, '');

      List<String> keys = file.split('/');

      hierarchyNodes = await createNode(hierarchyNodes, keys, 0, document);
    }
    treeViewController = treeViewController.copyWith(children: hierarchyNodes);

    setState(() {});
  }

  Future<List<Node>> createNode(List<Node> children, List<String> keys, int depth, FileSystemEntity document) async {
    Node? target;

    for (var child in children) {
      if (child.key == keys.getRange(0, depth + 1).join('/')) target = child;
    }

    if (target == null) {
      FileSystemEntityType type = (await document.stat()).type;
      IconData? icon;
      bool isFolder = false;

      if (type == FileSystemEntityType.directory) {
        icon = Icons.folder_rounded;
        isFolder = true;
      } else {
        String extension = keys.last.split('.').last;

        if (extension == 'txt') {
          icon = Icons.insert_drive_file;
        } else {
          icon = Icons.question_mark;
        }
      }

      return [
        ...children,
        Node(
          key: keys.join('/'),
          label: keys.last,
          data: document,
          icon: icon,
          parent: isFolder,
        ),
      ];
    } else {
      return [
        target.copyWith(
          children: [
            ...await createNode(target.children, keys, depth + 1, document),
          ],
        )
      ];
    }
  }

  void onNodeTap(String key) {
    Node? node = treeViewController.getNode(key);

    if (node != null) {
      widget.onSelectedChange?.call(node.data);
    }

    setState(() {
      selectedNode = key;
    });
  }

  void onExpansionChanged(String key, bool state) {
    Node? node = treeViewController.getNode(key);
    if (node != null) {
      List<Node> updated = treeViewController.updateNode(key, node.copyWith(expanded: state));
      treeViewController = treeViewController.copyWith(children: updated);
      setState(() {});
    }
  }

  TreeViewTheme theme = const TreeViewTheme(
    expanderTheme: ExpanderThemeData(
      type: ExpanderType.plusMinus,
      modifier: ExpanderModifier.none,
      position: ExpanderPosition.end,
      size: 20,
    ),
  );

  Widget nodeBuilder(BuildContext context, Node node) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Container(
            height: 16,
            width: 1.5,
            color: node.key == selectedNode ? Colors.lightBlue : Colors.transparent,
          ),
          Icon(node.icon),
          const SizedBox(width: 4),
          Text(node.label),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Expanded(
            child: TreeView(
              controller: treeViewController,
              shrinkWrap: false,
              allowParentSelect: true,
              onNodeTap: onNodeTap,
              onExpansionChanged: onExpansionChanged,
              theme: theme,
              nodeBuilder: nodeBuilder,
            ),
          ),
          Card(
            elevation: 5,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.create_new_folder),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.note_add),
                ),
                Container(
                  height: 16,
                  width: 1.5,
                  color: Colors.black,
                ),
                const Spacer(),
                if (selectedNode != null)
                  MaterialButton(
                    onPressed: () async {
                      Node? node = treeViewController.getNode(selectedNode!);
                      if (node == null) return;

                      String? newName = await showDialog(
                          context: context,
                          builder: (context) {
                            var controller = TextEditingController();

                            return AlertDialog(
                              content: TextField(
                                controller: controller,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  labelText: 'New name',
                                ),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                ElevatedButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Rename')),
                              ],
                            );
                          });

                      if (newName == null) return;

                      if (node.isParent) {
                        var directory = Directory(node.data.path);
                        directory.renameSync('${widget.path}/newName');
                      } else {
                        var file = File(node.data.path);
                        file.renameSync('${widget.path}/$newName.txt');
                      }

                      readFileList();
                    },
                    child: const Text('Rename'),
                  ),
                if (selectedNode != null)
                  MaterialButton(
                    onPressed: () {},
                    child: const Text('Move'),
                  ),
                if (selectedNode != null)
                  MaterialButton(
                    onPressed: () {
                      Node? node = treeViewController.getNode(selectedNode!);
                      if (node == null) return;

                      if (node.isParent) {
                        var directory = Directory(node.data.path);
                        directory.deleteSync();
                      } else {
                        var file = File(node.data.path);
                        file.deleteSync();
                      }

                      readFileList();
                    },
                    child: const Text('Delete'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
