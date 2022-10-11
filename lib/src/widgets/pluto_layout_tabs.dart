import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pluto_layout/pluto_layout.dart';
import 'package:pluto_layout/src/helper/resize_helper.dart';

class _ItemsNotifier extends StateNotifier<List<PlutoLayoutTabItem>> {
  _ItemsNotifier(List<PlutoLayoutTabItem> items) : super(items);

  void setEnabled(Object id, bool flag, [bool disableOther = false]) {
    PlutoLayoutTabItem disableOrNot(PlutoLayoutTabItem item) {
      if (!disableOther) return item;
      return item.copyWith(enabled: false);
    }

    state = [
      for (final item in state)
        if (item.id == id) item.copyWith(enabled: flag) else disableOrNot(item),
    ];
  }
}

final _itemProvider =
    StateNotifierProvider<_ItemsNotifier, List<PlutoLayoutTabItem>>((ref) {
  return _ItemsNotifier([]);
});

class PlutoLayoutTabs extends ConsumerWidget {
  const PlutoLayoutTabs({
    this.items = const [],
    this.mode = PlutoLayoutTabMode.showOne,
    super.key,
  });

  final List<PlutoLayoutTabItem> items;

  final PlutoLayoutTabMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    final containerDirection = ref.read(layoutContainerDirectionProvider);

    List<Widget> children = [
      _Menus(direction: containerDirection, mode: mode),
      _TabView(direction: containerDirection),
    ];

    Widget container = containerDirection.isHorizontal
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: containerDirection.isLeft
                ? children
                : children.reversed.toList(),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: containerDirection.isTop
                ? children
                : children.reversed.toList(),
          );

    return ProviderScope(
      overrides: [
        _itemProvider.overrideWithProvider(
          StateNotifierProvider<_ItemsNotifier, List<PlutoLayoutTabItem>>(
              (ref) {
            return _ItemsNotifier(items);
          }),
        ),
      ],
      child: ColoredBox(
        color: theme.dialogBackgroundColor,
        child: container,
      ),
    );
  }
}

class _Menus extends ConsumerWidget {
  const _Menus({required this.direction, required this.mode});

  final PlutoLayoutContainerDirection direction;

  final PlutoLayoutTabMode mode;

  MainAxisAlignment getMenuAlignment(PlutoLayoutId id) {
    switch (id) {
      case PlutoLayoutId.top:
        return MainAxisAlignment.start;
      case PlutoLayoutId.left:
        return MainAxisAlignment.end;
      case PlutoLayoutId.right:
        return MainAxisAlignment.start;
      case PlutoLayoutId.bottom:
        return MainAxisAlignment.start;
      case PlutoLayoutId.body:
        return MainAxisAlignment.start;
    }
  }

  int getMenuRotate(PlutoLayoutId id) {
    switch (id) {
      case PlutoLayoutId.top:
        return 0;
      case PlutoLayoutId.left:
        return -45;
      case PlutoLayoutId.right:
        return 45;
      case PlutoLayoutId.bottom:
        return 0;
      case PlutoLayoutId.body:
        return 0;
    }
  }

  void toggleTab(WidgetRef ref, PlutoLayoutTabItem item, bool flag) {
    final layoutData = ref.read(layoutDataProvider);

    final layoutId = ref.read(layoutIdProvider);

    ref.read(_itemProvider.notifier).setEnabled(item.id, flag, mode.isShowOne);

    final items = ref.read(_itemProvider).where((e) => e.enabled);

    final maxSize = layoutData.getMaxTabSize(layoutId);

    final sizing = AutoSizeHelper.items(
      maxSize: maxSize,
      length: items.length,
      itemMinSize: PlutoLayoutData.minTabSize,
      mode: AutoSizeMode.equal,
    );

    setSize(e) => e.size = sizing.getItemSize(e.size);
    items.forEach(setSize);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layoutId = ref.read(layoutIdProvider);

    final items = ref.watch(_itemProvider);

    return Align(
      alignment:
          direction.isVertical ? Alignment.centerLeft : Alignment.topCenter,
      child: RotatedBox(
        quarterTurns: getMenuRotate(layoutId),
        child: SingleChildScrollView(
          reverse: direction.isLeft,
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: getMenuAlignment(layoutId),
            children: (direction.isLeft ? items.reversed : items)
                .map(
                  (e) => ToggleButton(
                    title: e.title,
                    icon: e.icon,
                    enabled: e.enabled,
                    changed: (flag) => toggleTab(ref, e, flag),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _TabView extends ConsumerStatefulWidget {
  const _TabView({required this.direction});

  final PlutoLayoutContainerDirection direction;

  @override
  ConsumerState<_TabView> createState() => _TabViewState();
}

class _TabViewState extends ConsumerState<_TabView> {
  final ValueNotifier<double?> tabSize = ValueNotifier(null);

  final ChangeNotifier itemResizeNotifier = ChangeNotifier();

  Size get maxSize => MediaQuery.of(context).size;

  PlutoLayoutContainerDirection get direction => widget.direction;

  ResizeIndicatorPosition get tabViewResizePosition {
    switch (direction) {
      case PlutoLayoutContainerDirection.top:
        return ResizeIndicatorPosition.bottom;
      case PlutoLayoutContainerDirection.left:
        return ResizeIndicatorPosition.right;
      case PlutoLayoutContainerDirection.right:
        return ResizeIndicatorPosition.left;
      case PlutoLayoutContainerDirection.bottom:
        return ResizeIndicatorPosition.top;
    }
  }

  ResizeIndicatorPosition get tabItemResizePosition {
    switch (direction) {
      case PlutoLayoutContainerDirection.top:
        return ResizeIndicatorPosition.right;
      case PlutoLayoutContainerDirection.left:
        return ResizeIndicatorPosition.bottom;
      case PlutoLayoutContainerDirection.right:
        return ResizeIndicatorPosition.bottom;
      case PlutoLayoutContainerDirection.bottom:
        return ResizeIndicatorPosition.right;
    }
  }

  @override
  void dispose() {
    tabSize.dispose();

    super.dispose();
  }

  void resizeTabView(PlutoLayoutId id, Offset offset) {
    ref.read(layoutFocusedIdProvider.notifier).state = id;

    final constrains = ref.read(layoutDataProvider);
    double size = 0;
    double old = tabSize.value ??
        (direction.isHorizontal
            ? constrains.defaultTabWidth
            : constrains.defaultTabHeight);

    switch (direction) {
      case PlutoLayoutContainerDirection.top:
        size = old + offset.dy;
        break;
      case PlutoLayoutContainerDirection.left:
        size = old + offset.dx;
        break;
      case PlutoLayoutContainerDirection.right:
        size = old - offset.dx;
        break;
      case PlutoLayoutContainerDirection.bottom:
        size = old - offset.dy;
        break;
    }

    if (size <= PlutoLayoutData.minTabSize) return;

    tabSize.value = size;
  }

  void resizeTabItem(PlutoLayoutTabItem item, Offset offset) {
    final layoutData = ref.read(layoutDataProvider);

    final items = ref.read(_itemProvider).where(isEnabledItem).toList();

    final maxSize = direction.isHorizontal
        ? layoutData.leftSize.height
        : layoutData.topSize.width;

    final defaultSize = maxSize / items.length;

    for (final item in items) {
      if (item.size == 0) item.size = defaultSize;
    }

    final resizing = ResizeHelper.items(
      offset: direction.isHorizontal ? offset.dy : offset.dx,
      items: items,
      isMainItem: (i) => i.id == item.id,
      getItemSize: (i) => i.size,
      getItemMinSize: (i) => PlutoLayoutData.minTabSize,
      setItemSize: (i, size) => i.size = size,
      mode: ResizeMode.pushAndPull,
    );

    resizing.update();

    // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
    itemResizeNotifier.notifyListeners();
  }

  bool isEnabledItem(e) => e.enabled && e.tabViewBuilder != null;

  @override
  Widget build(BuildContext context) {
    final enabledItems = ref.watch(_itemProvider).where(isEnabledItem);

    if (enabledItems.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    final layoutId = ref.read(layoutIdProvider);

    final layoutData = ref.read(layoutDataProvider);

    final border = BorderSide(color: theme.dividerColor);

    final children = <Widget>[];

    int length = enabledItems.length;
    for (int i = 0; i < length; i += 1) {
      final item = enabledItems.elementAt(i);
      Widget child = item.tabViewBuilder!(context);
      if (i < length - 1) {
        child = ResizeIndicator<PlutoLayoutTabItem>(
          item: item,
          onResize: resizeTabItem,
          position: tabItemResizePosition,
          child: child,
        );
      }
      children.add(LayoutId(id: item.id, child: child));
    }

    return CustomSingleChildLayout(
      delegate: _TabViewDelegate(direction, tabSize, layoutData),
      child: ResizeIndicator<PlutoLayoutId>(
        item: layoutId,
        position: tabViewResizePosition,
        onResize: resizeTabView,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: direction.isTop ? border : BorderSide.none,
              left: direction.isLeft ? border : BorderSide.none,
              right: direction.isRight ? border : BorderSide.none,
              bottom: direction.isBottom ? border : BorderSide.none,
            ),
          ),
          child: CustomMultiChildLayout(
            delegate: _TabItemsDelegate(
              direction,
              enabledItems,
              itemResizeNotifier,
            ),
            children: children,
          ),
        ),
      ),
    );
  }
}

class _TabViewDelegate extends SingleChildLayoutDelegate {
  _TabViewDelegate(this.direction, this.tabSize, this.layoutData)
      : super(relayout: tabSize);

  final PlutoLayoutContainerDirection direction;

  final ValueNotifier<double?> tabSize;

  final PlutoLayoutData layoutData;

  double get defaultHeight => layoutData.defaultTabHeight;

  double get defaultWidth => layoutData.defaultTabWidth;

  @override
  Size getSize(BoxConstraints constraints) {
    switch (direction) {
      case PlutoLayoutContainerDirection.top:
        return Size(constraints.maxWidth, tabSize.value ?? defaultHeight);
      case PlutoLayoutContainerDirection.left:
        return Size(tabSize.value ?? defaultWidth, constraints.maxHeight);
      case PlutoLayoutContainerDirection.right:
        return Size(tabSize.value ?? defaultWidth, constraints.maxHeight);
      case PlutoLayoutContainerDirection.bottom:
        return Size(constraints.maxWidth, tabSize.value ?? defaultHeight);
    }
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    return Offset.zero;
  }

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    switch (direction) {
      case PlutoLayoutContainerDirection.top:
        return constraints.tighten(
          width: constraints.maxWidth,
          height: tabSize.value ?? defaultHeight,
        );
      case PlutoLayoutContainerDirection.left:
        return constraints.tighten(
          width: tabSize.value ?? defaultWidth,
          height: constraints.maxHeight,
        );
      case PlutoLayoutContainerDirection.right:
        return constraints.tighten(
          width: tabSize.value ?? defaultWidth,
          height: constraints.maxHeight,
        );
      case PlutoLayoutContainerDirection.bottom:
        return constraints.tighten(
          width: constraints.maxWidth,
          height: tabSize.value ?? defaultHeight,
        );
    }
  }

  @override
  bool shouldRelayout(covariant SingleChildLayoutDelegate oldDelegate) {
    return true;
  }
}

class _TabItemsDelegate extends MultiChildLayoutDelegate {
  _TabItemsDelegate(this.direction, this.items, Listenable notifier)
      : super(relayout: notifier);

  final PlutoLayoutContainerDirection direction;

  final Iterable<PlutoLayoutTabItem> items;

  Size _previousSize = Size.zero;

  @override
  void performLayout(Size size) {
    _reset(size);

    final length = items.length;
    final double defaultSize = max(
      direction.isHorizontal ? size.height / length : size.width / length,
      0,
    );
    int count = 0;
    double position = 0;
    double remaining = direction.isHorizontal ? size.height : size.width;
    isLast(int c) => c + 1 == length;

    for (final item in items) {
      if (item.size.isNaN) item.size = defaultSize;
      if (isLast(count)) item.size = max(remaining, 0);

      final constrain = direction.isHorizontal
          ? BoxConstraints.tight(
              Size(
                max(size.width, 0),
                max(item.size == 0 ? defaultSize : item.size, 0),
              ),
            )
          : BoxConstraints.tight(
              Size(
                max(item.size == 0 ? defaultSize : item.size, 0),
                max(size.height, 0),
              ),
            );

      if (hasChild(item.id)) {
        final s = layoutChild(item.id, constrain);
        item.size = direction.isHorizontal ? s.height : s.width;
        positionChild(
          item.id,
          Offset(
            direction.isHorizontal ? 0 : position,
            direction.isHorizontal ? position : 0,
          ),
        );
        position += direction.isHorizontal ? s.height : s.width;
        remaining -= item.size;
      }
    }

    _previousSize = size;
  }

  void _reset(Size size) {
    if (_previousSize == Size.zero) return;
    if (_previousSize == size) return;

    final current = direction.isHorizontal ? size.height : size.width;
    final previous =
        direction.isHorizontal ? _previousSize.height : _previousSize.width;
    final diff = current - previous;

    for (final item in items) {
      item.size += (item.size / previous) * diff;
    }
  }

  @override
  bool shouldRelayout(covariant MultiChildLayoutDelegate oldDelegate) {
    return true;
  }
}

class PlutoLayoutTabItem {
  PlutoLayoutTabItem({
    required this.id,
    required this.title,
    this.icon,
    this.tabViewBuilder,
    this.enabled = false,
    this.size = 0,
  });

  final Object id;

  final String title;

  final Widget? icon;

  final Widget Function(BuildContext context)? tabViewBuilder;

  final bool enabled;

  double size = 0;

  PlutoLayoutTabItem copyWith({
    Object? id,
    String? title,
    Widget? icon,
    Widget Function(BuildContext context)? tabViewBuilder,
    bool? enabled,
    double? size,
  }) {
    return PlutoLayoutTabItem(
      id: id ?? this.id,
      title: title ?? this.title,
      icon: icon ?? this.icon,
      tabViewBuilder: tabViewBuilder ?? this.tabViewBuilder,
      enabled: enabled ?? this.enabled,
      size: size ?? this.size,
    );
  }
}

enum PlutoLayoutTabMode {
  showOne,
  showSelected;

  bool get isShowOne => this == PlutoLayoutTabMode.showOne;
  bool get isShowSelected => this == PlutoLayoutTabMode.showSelected;
}
