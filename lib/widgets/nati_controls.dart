import 'package:flutter/material.dart';

import '../theme/nati_tokens.dart';

/// Flutter port of `input[natiUiInput]` + `.natiUiField` (label, 44px, focus ring).
class NatiInput extends StatefulWidget {
  const NatiInput({
    super.key,
    required this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.onChanged,
    this.onSubmitted,
    this.trailing,
    this.leading,
    this.autofocus = false,
  });

  final bool autofocus;
  final Widget? leading;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? trailing;

  @override
  State<NatiInput> createState() => _NatiInputState();
}

class _NatiInputState extends State<NatiInput> {
  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  void _onFocus() => setState(() {});

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = NatiTheme.of(context);
    final focused = _focus.hasFocus;
    final borderColor = focused ? t.primary : (_hover ? t.inputBorderHover : t.inputBorder);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(widget.label!,
              style: TextStyle(fontSize: NatiSize.fontSm, fontWeight: FontWeight.w500, color: t.label)),
          const SizedBox(height: NatiSize.space1),
        ],
        MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: AnimatedContainer(
            duration: NatiSize.quick,
            curve: const Cubic(0.4, 0, 0.2, 1),
            height: NatiSize.controlHeightMd,
            decoration: BoxDecoration(
              color: t.isDark ? NatiColors.neutralDark[0] : NatiColors.neutralLight[0],
              borderRadius: BorderRadius.circular(NatiSize.radiusMd),
              border: Border.all(color: borderColor),
              boxShadow: [
                if (focused)
                  BoxShadow(color: t.primary.withValues(alpha: 0.25), spreadRadius: NatiSize.focusRingWidth),
              ],
            ),
            child: Row(
              children: [
                if (widget.leading != null)
                  Padding(padding: const EdgeInsets.only(left: NatiSize.space3), child: widget.leading),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focus,
                    autofocus: widget.autofocus,
                    onChanged: widget.onChanged,
                    onSubmitted: widget.onSubmitted,
                    textInputAction: TextInputAction.search,
                    autocorrect: false,
                    enableSuggestions: false,
                    textCapitalization: TextCapitalization.sentences,
                    cursorColor: t.primary,
                    style: TextStyle(fontSize: NatiSize.fontMd + 1, color: t.text),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: widget.hint,
                      hintStyle: TextStyle(color: t.placeholder),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: widget.leading != null ? NatiSize.space2 + 2 : NatiSize.controlPaddingXMd,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                if (widget.trailing != null) widget.trailing!,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Select with type-to-filter, built on [NatiInput] so it looks identical
/// (label above, 44px, same border and focus ring). Arrow keys + Enter work.
/// Not in the Angular nati-ui-components yet - candidate for `<nati-ui-combobox>`.
class NatiCombobox<T extends Object> extends StatefulWidget {
  const NatiCombobox({
    super.key,
    required this.items,
    required this.selected,
    required this.itemLabel,
    required this.onSelected,
    this.label,
    this.hint,
    this.leading,
    this.maxMenuHeight = 280,
  });

  final List<T> items;
  final T selected;
  final String Function(T) itemLabel;
  final ValueChanged<T> onSelected;
  final String? label;
  final String? hint;
  final Widget? leading;
  final double maxMenuHeight;

  @override
  State<NatiCombobox<T>> createState() => _NatiComboboxState<T>();
}

class _NatiComboboxState<T extends Object> extends State<NatiCombobox<T>> {
  late final TextEditingController _controller = TextEditingController(text: widget.itemLabel(widget.selected));
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus) {
        // select everything so typing replaces the current value and filters
        _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
      } else {
        _controller.text = widget.itemLabel(widget.selected); // abandoned search -> restore
      }
    });
  }

  @override
  void didUpdateWidget(NatiCombobox<T> old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected && !_focus.hasFocus) {
      _controller.text = widget.itemLabel(widget.selected);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = NatiTheme.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      return RawAutocomplete<T>(
        textEditingController: _controller,
        focusNode: _focus,
        displayStringForOption: widget.itemLabel,
        optionsBuilder: (value) {
          final q = value.text.trim().toLowerCase();
          if (q.isEmpty || value.text == widget.itemLabel(widget.selected)) return widget.items;
          return widget.items.where((i) => widget.itemLabel(i).toLowerCase().contains(q));
        },
        onSelected: (item) {
          widget.onSelected(item);
          _focus.unfocus();
        },
        fieldViewBuilder: (context, controller, focus, onSubmitted) => NatiInput(
          controller: controller,
          focusNode: focus,
          label: widget.label,
          hint: widget.hint,
          leading: widget.leading,
          onSubmitted: (_) => onSubmitted(),
          trailing: Padding(
            padding: const EdgeInsets.only(right: NatiSize.space3),
            child: Icon(Icons.expand_more_rounded, size: 20, color: t.textMuted),
          ),
        ),
        optionsViewBuilder: (context, onSelected, options) {
          final list = options.toList();
          return Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: NatiSize.space1),
              child: Material(
                color: t.surface,
                elevation: 6,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(NatiSize.radiusMd),
                  side: BorderSide(color: t.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: widget.maxMenuHeight, maxWidth: constraints.maxWidth),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: NatiSize.space1),
                    shrinkWrap: true,
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final item = list[i];
                      final highlighted = AutocompleteHighlightedOption.of(context) == i;
                      final selected = item == widget.selected;
                      return InkWell(
                        onTap: () => onSelected(item),
                        child: Container(
                          color: highlighted ? t.primary.withValues(alpha: 0.10) : null,
                          padding: const EdgeInsets.symmetric(horizontal: NatiSize.controlPaddingXMd, vertical: 11),
                          child: Row(children: [
                            Expanded(
                              child: Text(widget.itemLabel(item),
                                  style: TextStyle(
                                    fontSize: NatiSize.fontMd,
                                    color: t.text,
                                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                  )),
                            ),
                            if (selected) Icon(Icons.check_rounded, size: 18, color: t.primary),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      );
    });
  }
}

/// Port of `button[natiUiButton]` primary/outline variants with loading spinner.
class NatiButton extends StatelessWidget {
  const NatiButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.outline = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool outline;

  @override
  Widget build(BuildContext context) {
    final t = NatiTheme.of(context);
    final fg = outline ? t.text : t.onPrimary;
    final enabled = onPressed != null && !loading;

    return Opacity(
      opacity: enabled || loading ? 1 : 0.55,
      child: Material(
        color: outline ? t.surface : t.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NatiSize.radiusMd),
          side: BorderSide(color: outline ? t.inputBorder : t.primary),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: Container(
            height: NatiSize.controlHeightMd,
            padding: const EdgeInsets.symmetric(horizontal: NatiSize.space4),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading)
                  SizedBox.square(
                    dimension: 15,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  )
                else if (icon != null)
                  Icon(icon, size: 18, color: fg),
                if (loading || icon != null) const SizedBox(width: NatiSize.space2),
                Text(label, style: TextStyle(fontSize: NatiSize.fontMd, fontWeight: FontWeight.w600, color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small pill used for suggestions / recent searches.
class NatiChip extends StatelessWidget {
  const NatiChip({super.key, required this.label, required this.onTap, this.icon});
  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = NatiTheme.of(context);
    return Material(
      color: t.surface.withValues(alpha: 0.9),
      shape: StadiumBorder(side: BorderSide(color: t.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 14, color: t.textMuted), const SizedBox(width: 6)],
            Text(label, style: TextStyle(fontSize: NatiSize.fontSm, color: t.text, fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}

/// Surface card (A1 `.completion`/card look: solid surface, 1px border, soft shadow).
class NatiCard extends StatelessWidget {
  const NatiCard({super.key, required this.child, this.padding, this.accent});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  /// Optional colors for a top accent bar (one per gender).
  final List<Color>? accent;

  @override
  Widget build(BuildContext context) {
    final t = NatiTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: t.surface.withValues(alpha: t.isDark ? 0.94 : 0.96),
        borderRadius: BorderRadius.circular(NatiSize.radiusLg),
        border: Border.all(color: t.border),
        boxShadow: t.shadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (accent != null && accent!.isNotEmpty)
            Container(
              height: 5,
              decoration: BoxDecoration(
                color: accent!.length == 1 ? accent!.first : null,
                gradient: accent!.length > 1 ? LinearGradient(colors: accent!) : null,
              ),
            ),
          Padding(padding: padding ?? const EdgeInsets.all(NatiSize.space5), child: child),
        ],
      ),
    );
  }
}
