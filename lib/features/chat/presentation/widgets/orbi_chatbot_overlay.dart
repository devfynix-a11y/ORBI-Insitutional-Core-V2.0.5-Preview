import 'package:flutter/material.dart';
import 'package:orbi_mobileapp/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/orbi_theme.dart';
import '../../../../core/widgets/orbi_logo.dart';
import '../../../../core/widgets/orbi_section_card.dart';
import '../../../../core/widgets/orbi_state_card.dart';
import '../../data/chat_local_store.dart';
import '../../data/chat_service.dart';

enum _ChatRole { assistant, user }

class _ChatMessage {
  final _ChatRole role;
  final String text;
  final DateTime timestamp;

  const _ChatMessage({
    required this.role,
    required this.text,
    required this.timestamp,
  });
}

class _ChatAvatarSpec {
  final IconData? icon;
  final bool useOrbiLogo;
  final Color background;
  final Color iconColor;
  final bool showBorder;
  final double size;

  const _ChatAvatarSpec({
    this.icon,
    this.useOrbiLogo = false,
    required this.background,
    required this.iconColor,
    this.showBorder = true,
    this.size = 28,
  });
}

class OrbiChatbotOverlay extends StatefulWidget {
  final VoidCallback? onInteraction;

  const OrbiChatbotOverlay({super.key, this.onInteraction});

  @override
  State<OrbiChatbotOverlay> createState() => _OrbiChatbotOverlayState();
}

class _OrbiChatbotOverlayState extends State<OrbiChatbotOverlay> {
  final ChatService _chatService = ChatService();
  final ChatLocalStore _chatLocalStore = ChatLocalStore();
  final TextEditingController _composerController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _composerFocusNode = FocusNode();

  final List<_ChatMessage> _messages = <_ChatMessage>[];

  bool _isOpen = false;
  bool _isLoading = false;
  bool _initialized = false;
  bool _restoring = true;
  String? _conversationId;
  String? _loadError;
  Offset _triggerOffset = Offset.zero;
  Offset _triggerOffsetAtDragStart = Offset.zero;
  bool _isDraggingTrigger = false;

  @override
  void initState() {
    super.initState();
    _restoreConversation();
  }

  @override
  void dispose() {
    _composerController.dispose();
    _scrollController.dispose();
    _composerFocusNode.dispose();
    super.dispose();
  }

  void _toggleOpen() {
    widget.onInteraction?.call();
    setState(() => _isOpen = !_isOpen);
    if (_isOpen) {
      _ensureGreeting();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _composerFocusNode.requestFocus();
        }
      });
    } else {
      _composerFocusNode.unfocus();
    }
  }

  Future<void> _ensureGreeting() async {
    if (_restoring || _initialized || _isLoading) return;

    setState(() {
      _initialized = true;
      _isLoading = true;
      _loadError = null;
    });

    try {
      final reply = await _chatService.initialize(
        conversationId: _conversationId,
      );
      if (!mounted) return;
      setState(() {
        _conversationId = reply.conversationId ?? _conversationId;
        _messages.add(_assistantMessage(reply.text));
        _isLoading = false;
      });
      await _persistConversation();
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      final message = _toErrorMessage(error);
      setState(() {
        _isLoading = false;
        _loadError = message;
      });
      _showErrorSnack(message);
    }
  }

  Future<void> _sendMessage() async {
    final message = _composerController.text.trim();
    if (message.isEmpty || _isLoading) return;

    widget.onInteraction?.call();
    _composerController.clear();

    setState(() {
      _loadError = null;
      _messages.add(_userMessage(message));
      _isLoading = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _composerFocusNode.requestFocus();
      }
    });
    await _persistConversation();
    _scrollToBottom();

    try {
      final reply = await _chatService.sendMessage(
        message,
        conversationId: _conversationId,
      );
      if (!mounted) return;
      setState(() {
        _conversationId = reply.conversationId ?? _conversationId;
        _messages.add(_assistantMessage(reply.text));
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _composerFocusNode.requestFocus();
        }
      });
      await _persistConversation();
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      final message = _toErrorMessage(error);
      setState(() => _isLoading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _composerFocusNode.requestFocus();
        }
      });
      _showErrorSnack(message);
    }
  }

  String _toErrorMessage(Object error) {
    final l10n = AppLocalizations.of(context)!;
    final text = error.toString().toLowerCase();
    if (text.contains('401') ||
        text.contains('403') ||
        text.contains('unauthorized')) {
      return l10n.chatSessionUnavailableMessage;
    }
    if (text.contains('socket') ||
        text.contains('timeout') ||
        text.contains('network') ||
        text.contains('failed host lookup')) {
      return l10n.chatConnectionFailedMessage;
    }
    return l10n.chatUnavailableMessage;
  }

  void _showErrorSnack(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _restoreConversation() async {
    final storedConversationId = await _chatLocalStore.loadConversationId();
    final storedMessages = await _chatLocalStore.loadMessages();
    if (!mounted) return;
    setState(() {
      _conversationId = storedConversationId;
      _messages
        ..clear()
        ..addAll(
          storedMessages.map(
            (message) => _ChatMessage(
              role: message.role == 'user'
                  ? _ChatRole.user
                  : _ChatRole.assistant,
              text: message.text,
              timestamp: message.timestamp,
            ),
          ),
        );
      _initialized = _messages.isNotEmpty;
      _restoring = false;
    });
  }

  Future<void> _persistConversation() {
    return _chatLocalStore.saveConversation(
      conversationId: _conversationId,
      messages: _messages
          .map(
            (message) => StoredChatMessage(
              role: message.role == _ChatRole.user ? 'user' : 'assistant',
              text: message.text,
              timestamp: message.timestamp,
            ),
          )
          .toList(),
    );
  }

  Future<void> _clearConversation() async {
    if (_isLoading) return;
    widget.onInteraction?.call();
    setState(() {
      _messages.clear();
      _conversationId = null;
      _initialized = false;
      _loadError = null;
    });
    await _chatLocalStore.clear();
    if (!mounted) return;
    _ensureGreeting();
  }

  _ChatMessage _assistantMessage(String text) => _ChatMessage(
    role: _ChatRole.assistant,
    text: text,
    timestamp: DateTime.now(),
  );

  _ChatMessage _userMessage(String text) =>
      _ChatMessage(role: _ChatRole.user, text: text, timestamp: DateTime.now());

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final ui = OrbiTheme.uiOf(context);
    final surfaces = OrbiTheme.surfacesOf(context);
    final isCompact = mediaQuery.size.width < 720;
    final bottomSafe = mediaQuery.padding.bottom;
    final keyboardInset = mediaQuery.viewInsets.bottom;
    final double panelInset = isCompact ? 8.0 : 20.0;
    final double panelTop = isCompact ? mediaQuery.padding.top + 8.0 : 86.0;
    final double panelBottom = keyboardInset > 0
        ? keyboardInset + 8.0
        : (isCompact ? 8.0 + bottomSafe : 108.0 + bottomSafe);
    final double panelHeight = mediaQuery.size.height - panelTop - panelBottom;
    final double triggerBottom = (_isOpen && keyboardInset > 0)
        ? keyboardInset + 12.0
        : 136.0 + bottomSafe;
    const double triggerSize = 58.0;
    final double triggerLeftBase = mediaQuery.size.width - triggerSize - 16.0;
    final double triggerLeft = (triggerLeftBase + _triggerOffset.dx).clamp(
      8.0,
      mediaQuery.size.width - triggerSize - 8.0,
    );
    final double triggerBottomClamped = (triggerBottom + _triggerOffset.dy)
        .clamp(
          keyboardInset > 0 ? keyboardInset + 8.0 : 8.0,
          mediaQuery.size.height - triggerSize - panelTop,
        );
    final bool showTrigger = !_isOpen || keyboardInset == 0;

    return IgnorePointer(
      ignoring: false,
      child: Stack(
        children: [
          if (_isOpen)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: isCompact ? null : _toggleOpen,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _isOpen ? 1 : 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: surfaces.overlay),
                  ),
                ),
              ),
            ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            right: panelInset,
            left: isCompact ? panelInset : null,
            top: _isOpen ? panelTop : mediaQuery.size.height,
            bottom: _isOpen ? panelBottom : -760,
            child: IgnorePointer(
              ignoring: !_isOpen,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _isOpen ? 1 : 0,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isCompact
                        ? mediaQuery.size.width - (panelInset * 2)
                        : 420.0,
                    maxHeight: panelHeight.clamp(260.0, 620.0),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(isCompact ? 24 : 26),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x4D000000),
                          blurRadius: 32,
                          offset: Offset(0, 14),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(isCompact ? 24 : 26),
                      child: Material(
                        color: Colors.transparent,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [ui.card, ui.cardStrong],
                            ),
                            border: Border.all(color: ui.borderStrong),
                          ),
                          child: Column(
                            children: [
                              _buildHeader(ui, surfaces, isCompact),
                              Expanded(child: _buildConversation(context, ui)),
                              _buildComposer(context, ui, isCompact),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (showTrigger)
            Positioned(
              left: triggerLeft,
              bottom: triggerBottomClamped,
              child: SafeArea(
                top: false,
                left: false,
                child: GestureDetector(
                  onLongPressStart: (_) async {
                    await HapticFeedback.mediumImpact();
                    if (!mounted) return;
                    setState(() {
                      _triggerOffsetAtDragStart = _triggerOffset;
                      _isDraggingTrigger = true;
                    });
                  },
                  onLongPressMoveUpdate: (details) {
                    setState(() {
                      _triggerOffset = Offset(
                        _triggerOffsetAtDragStart.dx +
                            details.offsetFromOrigin.dx,
                        _triggerOffsetAtDragStart.dy -
                            details.offsetFromOrigin.dy,
                      );
                    });
                  },
                  onLongPressEnd: (_) {
                    if (!mounted) return;
                    setState(() {
                      _isDraggingTrigger = false;
                    });
                  },
                  child: Semantics(
                    button: true,
                    label: _isOpen
                        ? AppLocalizations.of(context)!.chatCloseSemantics
                        : AppLocalizations.of(context)!.chatOpenSemantics,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _isDraggingTrigger ? null : _toggleOpen,
                        borderRadius: BorderRadius.circular(999),
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutBack,
                          scale: _isDraggingTrigger ? 1.08 : 1,
                          child: Transform.translate(
                            offset: Offset(0, _isDraggingTrigger ? -5 : -2),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              width: triggerSize,
                              height: triggerSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: _isOpen
                                      ? [
                                          ui.cardStrong,
                                          Color.lerp(
                                                ui.cardStrong,
                                                ui.accent,
                                                0.28,
                                              ) ??
                                              ui.cardStrong,
                                        ]
                                      : [
                                          Color.lerp(
                                                ui.accent,
                                                Colors.white,
                                                0.14,
                                              ) ??
                                              ui.accent,
                                          ui.accent,
                                          Color.lerp(
                                                ui.accent,
                                                Colors.black,
                                                0.20,
                                              ) ??
                                              ui.accent,
                                        ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                      alpha: _isOpen ? 0.30 : 0.26,
                                    ),
                                    blurRadius: 10,
                                    spreadRadius: -3,
                                    offset: const Offset(0, 7),
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 22,
                                    spreadRadius: -5,
                                    offset: const Offset(0, 17),
                                  ),
                                  BoxShadow(
                                    color: ui.accent.withValues(
                                      alpha: _isDraggingTrigger ? 0.34 : 0.24,
                                    ),
                                    blurRadius: _isDraggingTrigger ? 36 : 28,
                                    spreadRadius: _isDraggingTrigger ? 4 : 1,
                                    offset: const Offset(0, 13),
                                  ),
                                ],
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Positioned(
                                    top: 5,
                                    left: 12,
                                    right: 12,
                                    child: Container(
                                      height: 9,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.white.withValues(
                                              alpha: 0.34,
                                            ),
                                            Colors.white.withValues(
                                              alpha: 0.02,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 14,
                                    ),
                                    child: AnimatedScale(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      scale: _isOpen ? 0.92 : 1.0,
                                      child: OrbiLogoV2(
                                        width: 44,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 3,
                                    bottom: 3,
                                    child: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      transitionBuilder: (child, animation) =>
                                          ScaleTransition(
                                            scale: animation,
                                            child: FadeTransition(
                                              opacity: animation,
                                              child: child,
                                            ),
                                          ),
                                      child: Container(
                                        key: ValueKey<bool>(_isOpen),
                                        width: 21,
                                        height: 21,
                                        decoration: BoxDecoration(
                                          color: _isOpen
                                              ? ui.danger
                                              : Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.20,
                                              ),
                                              blurRadius: 7,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          _isOpen
                                              ? Icons.close_rounded
                                              : Icons.chat_bubble_rounded,
                                          size: 11,
                                          color: _isOpen
                                              ? Colors.white
                                              : ui.accent,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    OrbiUiTokens ui,
    OrbiSurfaceTokens surfaces,
    bool isCompact,
  ) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        isCompact ? 14 : 18,
        14,
        isCompact ? 14 : 18,
        12,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [surfaces.shellStart, surfaces.shellEnd],
        ),
        border: Border(bottom: BorderSide(color: ui.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: ui.cardMuted,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ui.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 12,
                    ),
                    child: const OrbiLogoV2(width: 42),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.chatTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.michroma(
                        color: ui.textPrimary,
                        fontSize: 13,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppLocalizations.of(context)!.chatSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.jetBrainsMono(
                        color: ui.textSoft,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: AppLocalizations.of(context)!.chatResetTooltip,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 36,
                ),
                padding: EdgeInsets.zero,
                onPressed: _clearConversation,
                icon: Icon(
                  Icons.restart_alt_rounded,
                  color: ui.iconMuted,
                  size: 19,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _headerChip(
                label: AppLocalizations.of(context)!.chatEncryptedLabel,
                color: ui.success,
                background: ui.successSoft,
                border: ui.border,
              ),
              _headerChip(
                label: AppLocalizations.of(context)!.chatPrivateSessionLabel,
                color: ui.textMuted,
                background: ui.cardMuted,
                border: ui.border,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerChip({
    required String label,
    required Color color,
    required Color background,
    required Color border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildConversation(BuildContext context, OrbiUiTokens ui) {
    if (_restoring) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_messages.isEmpty && _loadError != null && !_isLoading) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: OrbiStateCard(
          icon: Icons.cloud_off_rounded,
          title: AppLocalizations.of(context)!.chatUnavailableTitle,
          message: _loadError,
          accentColor: ui.danger,
          accentBackground: ui.dangerSoft,
          action: ElevatedButton.icon(
            onPressed: _ensureGreeting,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(AppLocalizations.of(context)!.actionRetry),
          ),
        ),
      );
    }

    if (_messages.isEmpty && !_isLoading) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: OrbiStateCard(
          icon: Icons.chat_bubble_outline_rounded,
          title: AppLocalizations.of(context)!.chatReadyTitle,
          message: AppLocalizations.of(context)!.chatReadyMessage,
          accentColor: ui.success,
          accentBackground: ui.successSoft,
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [ui.cardStrong.withValues(alpha: 0.72), ui.card],
        ),
      ),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        physics: const BouncingScrollPhysics(),
        itemCount: _messages.length + (_isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _messages.length) {
            return _buildTypingIndicator(ui);
          }
          final message = _messages[index];
          return _buildBubble(context, message, ui);
        },
      ),
    );
  }

  Widget _buildBubble(
    BuildContext context,
    _ChatMessage message,
    OrbiUiTokens ui,
  ) {
    final isUser = message.role == _ChatRole.user;
    final advanced = OrbiTheme.advancedOf(context);
    final bubbleColor = isUser ? ui.accent : advanced.chatBubbleBot;
    final borderColor = isUser ? ui.accent : ui.border;
    final textColor = isUser ? Colors.white : ui.textPrimary;
    final align = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final avatarSpec = _avatarSpecForMessage(isUser: isUser, ui: ui);
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isUser ? 18 : 6),
      bottomRight: Radius.circular(isUser ? 6 : 18),
    );

    return Align(
      alignment: align,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[
                _buildAvatar(spec: avatarSpec, ui: ui),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: isUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        borderRadius: radius,
                        border: Border.all(color: borderColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        message.text,
                        style: GoogleFonts.inter(
                          color: textColor,
                          fontSize: 13.5,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _formatTime(message.timestamp),
                      style: GoogleFonts.jetBrainsMono(
                        color: ui.textSoft,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 8),
                _buildAvatar(spec: avatarSpec, ui: ui),
              ],
            ],
          ),
        ),
      ),
    );
  }

  _ChatAvatarSpec _avatarSpecForMessage({
    required bool isUser,
    required OrbiUiTokens ui,
  }) {
    if (isUser) {
      return _ChatAvatarSpec(
        icon: Icons.person_rounded,
        background: ui.accent,
        iconColor: Colors.white,
      );
    }

    // AI assistant uses the Orbi logo. If chat is later switched to a live
    // agent, provide imageUrl instead and the same widget will render it.
    return _ChatAvatarSpec(
      useOrbiLogo: true,
      background: ui.cardMuted,
      iconColor: ui.success,
      showBorder: true,
      size: 34,
    );
  }

  Widget _buildAvatar({
    required _ChatAvatarSpec spec,
    required OrbiUiTokens ui,
  }) {
    return Container(
      width: spec.size,
      height: spec.size,
      decoration: BoxDecoration(
        color: spec.background,
        borderRadius: BorderRadius.circular(999),
        border: spec.showBorder ? Border.all(color: ui.border) : null,
      ),
      child: spec.useOrbiLogo
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 9),
              child: const FittedBox(
                fit: BoxFit.contain,
                child: OrbiLogoV2(width: 30),
              ),
            )
          : ClipOval(child: _fallbackAvatarIcon(spec)),
    );
  }

  Widget _fallbackAvatarIcon(_ChatAvatarSpec spec) {
    return Icon(
      spec.icon ?? Icons.support_agent_rounded,
      size: spec.size * 0.54,
      color: spec.iconColor,
    );
  }

  Widget _buildTypingIndicator(OrbiUiTokens ui) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildAvatar(
              spec: _avatarSpecForMessage(isUser: false, ui: ui),
              ui: ui,
            ),
            const SizedBox(width: 8),
            OrbiSectionCard(
              elevated: false,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(ui.success),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    AppLocalizations.of(context)!.chatTypingLabel,
                    style: GoogleFonts.inter(
                      color: ui.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer(BuildContext context, OrbiUiTokens ui, bool isCompact) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: ui.card,
        border: Border(top: BorderSide(color: ui.border)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: ui.cardMuted,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: ui.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _composerController,
                focusNode: _composerFocusNode,
                enabled: !_isLoading,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onChanged: (_) {
                  widget.onInteraction?.call();
                  setState(() {});
                },
                onSubmitted: (_) => _sendMessage(),
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: isCompact
                      ? AppLocalizations.of(context)!.chatComposerCompactHint
                      : AppLocalizations.of(context)!.chatComposerHint,
                  isDense: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.fromLTRB(6, 14, 8, 14),
                  hintStyle: GoogleFonts.inter(
                    color: ui.textSoft,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  prefixIcon: Icon(
                    Icons.mark_chat_unread_rounded,
                    color: ui.iconMuted,
                    size: 20,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 6, bottom: 6),
              child: Material(
                color: _composerController.text.trim().isEmpty || _isLoading
                    ? ui.cardStrong
                    : ui.accent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _composerController.text.trim().isEmpty || _isLoading
                      ? null
                      : _sendMessage,
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(
                      Icons.arrow_upward_rounded,
                      size: 18,
                      color:
                          _composerController.text.trim().isEmpty || _isLoading
                          ? ui.iconMuted
                          : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }
}
