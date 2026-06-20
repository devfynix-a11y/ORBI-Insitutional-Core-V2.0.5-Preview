import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ProviderLogoImage extends StatefulWidget {
  const ProviderLogoImage({
    super.key,
    required this.candidates,
    required this.placeholderColor,
    this.remoteLogoUrl,
    this.placeholderLabel = 'Logo',
    this.debugPathLabel,
    this.placeholderIcon = Icons.image_outlined,
    this.padding = const EdgeInsets.all(8),
    this.fit = BoxFit.contain,
  });

  final List<String> candidates;
  final Color placeholderColor;
  final String? remoteLogoUrl;
  final String placeholderLabel;
  final String? debugPathLabel;
  final IconData placeholderIcon;
  final EdgeInsetsGeometry padding;
  final BoxFit fit;

  @override
  State<ProviderLogoImage> createState() => _ProviderLogoImageState();
}

class _ProviderLogoImageState extends State<ProviderLogoImage> {
  static final Map<String, Uint8List> _bytesCache = <String, Uint8List>{};
  late Future<Uint8List?> _futureBytes;

  @override
  void initState() {
    super.initState();
    _futureBytes = _resolveFirstAvailable(widget.candidates);
  }

  @override
  void didUpdateWidget(covariant ProviderLogoImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameCandidates(oldWidget.candidates, widget.candidates)) {
      _futureBytes = _resolveFirstAvailable(widget.candidates);
    }
  }

  bool _sameCandidates(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<Uint8List?> _resolveFirstAvailable(List<String> candidates) async {
    for (final candidate in candidates) {
      final cached = _bytesCache[candidate];
      if (cached != null) {
        return cached;
      }
      try {
        final bytes = await rootBundle.load(candidate);
        final data = bytes.buffer.asUint8List();
        _bytesCache[candidate] = data;
        return data;
      } catch (_) {
        // Do not cache misses; stale bundles during hot reload can recover
        // after a full rebuild or asset refresh.
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _futureBytes,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes != null) {
          return Center(
            child: Padding(
              padding: widget.padding,
              child: Image.memory(
                bytes,
                fit: widget.fit,
                alignment: Alignment.center,
                filterQuality: FilterQuality.high,
              ),
            ),
          );
        }
        final remoteLogoUrl = widget.remoteLogoUrl?.trim() ?? '';
        if (remoteLogoUrl.startsWith('https://') ||
            remoteLogoUrl.startsWith('http://')) {
          return Center(
            child: Padding(
              padding: widget.padding,
              child: Image.network(
                remoteLogoUrl,
                fit: widget.fit,
                alignment: Alignment.center,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, _, _) => _ProviderLogoPlaceholder(
                  color: widget.placeholderColor,
                  icon: widget.placeholderIcon,
                  label: widget.placeholderLabel,
                  debugPathLabel: widget.debugPathLabel,
                ),
              ),
            ),
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) => _ProviderLogoPlaceholder(
            color: widget.placeholderColor,
            icon: widget.placeholderIcon,
            label: widget.placeholderLabel,
            debugPathLabel: widget.debugPathLabel,
          ),
        );
      },
    );
  }
}

class _ProviderLogoPlaceholder extends StatelessWidget {
  const _ProviderLogoPlaceholder({
    required this.color,
    required this.icon,
    required this.label,
    this.debugPathLabel,
  });

  final Color color;
  final IconData icon;
  final String label;
  final String? debugPathLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showDebugPath =
            (debugPathLabel ?? '').trim().isNotEmpty &&
            constraints.maxHeight >= 92;
        final compact = constraints.maxHeight < 74;
        final ultraCompact = constraints.maxHeight < 60;
        return Center(
          child: Container(
            width: double.infinity,
            height: double.infinity,
            margin: EdgeInsets.all(ultraCompact ? 2 : compact ? 4 : 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: color.withValues(alpha: 0.75),
                  size: ultraCompact ? 14 : compact ? 15 : 18,
                ),
                if (!ultraCompact) ...[
                  SizedBox(height: compact ? 2 : 3),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color.withValues(alpha: 0.72),
                      fontSize: compact ? 8 : 9.5,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ],
                if (showDebugPath) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      debugPathLabel!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: color.withValues(alpha: 0.6),
                        fontSize: 7.5,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
