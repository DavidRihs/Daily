import 'package:daily_stemys/database_service.dart';
import 'package:daily_stemys/sortable_shufflable_map.dart';
import 'package:flutter/material.dart';

class AttendeesWidget extends StatefulWidget {
  const AttendeesWidget(
      {super.key, required FocusNode attendeeTextFieldFocusNode})
      : _attendeeTextFieldFocusNode = attendeeTextFieldFocusNode;

  final FocusNode _attendeeTextFieldFocusNode;

  @override
  State<AttendeesWidget> createState() => AttendeesWidgetState();
}

class ResetClockNotification extends Notification {
  ResetClockNotification();
}

class AttendeesWidgetState extends State<AttendeesWidget> {
  final SortableShufflableMap _attendees = SortableShufflableMap();
  final TextEditingController _attendeeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    DatabaseService.loadData().then((result) {
      _attendees.addAll(result);
      _attendees.sortByBool();
      _attendees.shuffleTrueValues();
      setState(() {});
    });
  }

  bool next() {
    setState(() {
      _attendees.next();
    });
    return _attendees.hasActive();
  }

  void lock() => setState(() {
        _attendees.lock();
      });

  void unlock() => setState(() {
        _attendees.unlock();
      });

  bool isLocked() => _attendees.isLocked();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          TextField(
            focusNode: widget._attendeeTextFieldFocusNode,
            controller: _attendeeController,
            decoration: const InputDecoration(
              suffixIcon: Icon(Icons.person_add),
              labelText: 'Add attendees',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              setState(() {
                _attendees.add(value, true);
              });
              DatabaseService.addOrUpdate(value, true);
              _attendeeController.clear();
              widget._attendeeTextFieldFocusNode.requestFocus();
            },
          ),
          const SizedBox(
            height: 20,
          ),
          Expanded(
              child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            primary: true,
            shrinkWrap: true,
            itemCount: _attendees.getLength(),
            scrollDirection: Axis.vertical,
            itemBuilder: (context, index) {
              String key = _attendees.getKey(index);
              return Dismissible(
                  direction: DismissDirection.startToEnd,
                  background: Container(
                    padding: const EdgeInsets.only(left: 10),
                    color: Colors.red,
                    child: const Align(
                      alignment: Alignment.centerLeft,
                      child: Icon(
                        Icons.delete,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  onDismissed: (direction) {
                    setState(() => _attendees.remove(key));
                    DatabaseService.remove(key);
                  },
                  key: Key(key),
                  child: GestureDetector(
                      onDoubleTap: () => setState(() {
                            if (_attendees.setActive(key)) {
                              ResetClockNotification().dispatch(context);
                            }
                          }),
                      child: Card(
                          clipBehavior: Clip.none,
                          shape: ContinuousRectangleBorder(
                              side: BorderSide(
                                  color:
                                      Theme.of(context).colorScheme.surface)),
                          margin: const EdgeInsets.all(0),
                          child: ListTile(
                            trailing: ReorderableDragStartListener(
                                index: index,
                                child: const Icon(
                                  Icons.drag_handle,
                                  color: Colors.black,
                                )),
                            tileColor: _attendees.isActive(key)
                                ? Colors.yellow
                                : _attendees.get(key) ?? false
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.6),
                            leading: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Checkbox(
                                    side: WidgetStateBorderSide.resolveWith(
                                      (states) {
                                        return BorderSide(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .surface,
                                            width: 2,
                                            strokeAlign:
                                                BorderSide.strokeAlignOutside);
                                      },
                                    ),
                                    fillColor: const WidgetStatePropertyAll(
                                        Colors.white),
                                    value: _attendees.get(key) ?? false,
                                    onChanged: (value) {
                                      setState(() => _attendees.updateValue(
                                          key, value ?? false));
                                      DatabaseService.addOrUpdate(
                                          key, value ?? false);
                                    }),
                                _attendees.isKeyLocked(key)
                                    ? const Icon(
                                        Icons.lock,
                                        color: Colors.black,
                                      )
                                    : const SizedBox()
                              ],
                            ),
                            title: Text(key),
                          ))));
            },
            onReorder: (int oldIndex, int newIndex) {
              setState(() => _attendees.reorder(oldIndex, newIndex));
            },
          )),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ButtonStyle(
                  side: WidgetStatePropertyAll(BorderSide(
                      color: Theme.of(context).colorScheme.primary))),
              onPressed: () {
                setState(() {
                  _attendees.sortByBool();
                  _attendees.shuffleTrueValues();
                });
              },
              label: const Text('Randomize'),
              icon: const Icon(Icons.shuffle),
            ),
          ),
        ],
      ),
    );
  }
}
