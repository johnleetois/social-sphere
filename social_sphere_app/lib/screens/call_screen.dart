// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

const _bg = Color(0xFF0D0D1A);
const _surface = Color(0xFF1C1C2E);
const _primary = Color(0xFF7C5CF6);
const _textSecondary = Color(0xFF8B8BA7);
const _danger = Color(0xFFEF4444);
const _online = Color(0xFF10B981);

enum _CallState { ringing, calling, connected, ended }

class CallScreen extends StatefulWidget {
  final int peerId;
  final String peerUsername;
  final String? peerAvatarUrl;
  final String callType; // "audio" | "video"
  final int currentUserId;
  final String token;
  final bool isIncoming;

  const CallScreen({
    super.key,
    required this.peerId,
    required this.peerUsername,
    this.peerAvatarUrl,
    required this.callType,
    required this.currentUserId,
    required this.token,
    required this.isIncoming,
  });

  @override
  CallScreenState createState() => CallScreenState();
}

class CallScreenState extends State<CallScreen>
    with SingleTickerProviderStateMixin {
  WebSocketChannel? _channel;
  _CallState _state = _CallState.ringing;
  bool _muted = false;
  bool _cameraOff = false;
  int _callDuration = 0;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _connectWs();
  }

  void _connectWs() {
    final url = "ws://10.0.9.104:8000/ws/call?token=${widget.token}";
    _channel = WebSocketChannel.connect(Uri.parse(url));
    _channel!.stream.listen(
      (raw) {
        try {
          final data = jsonDecode(raw as String) as Map<String, dynamic>;
          _handleSignal(data);
        } catch (e) {
          log("Call WS parse error: $e");
        }
      },
      onError: (e) { log("Call WS error: $e"); _handleHangUp(); },
      onDone: () { log("Call WS done"); if (mounted && _state != _CallState.ended) _handleHangUp(); },
    );

    if (!widget.isIncoming) {
      // Send call request
      Future.delayed(const Duration(milliseconds: 500), () {
        _channel?.sink.add(jsonEncode({
          "type": "call_request",
          "target_id": widget.peerId,
          "call_type": widget.callType,
        }));
        if (mounted) setState(() => _state = _CallState.calling);
      });
    }
  }

  void _handleSignal(Map<String, dynamic> data) {
    if (!mounted) return;
    final type = data["type"] as String? ?? "";
    switch (type) {
      case "call_accept":
        setState(() {
          _state = _CallState.connected;
        });
        _startTimer();
        break;
      case "call_reject":
        setState(() => _state = _CallState.ended);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
        break;
      case "call_end":
        _handleHangUp();
        break;
    }
  }

  void _acceptCall() {
    _channel?.sink.add(jsonEncode({
      "type": "call_accept",
      "target_id": widget.peerId,
    }));
    setState(() => _state = _CallState.connected);
    _startTimer();
  }

  void _rejectCall() {
    _channel?.sink.add(jsonEncode({
      "type": "call_reject",
      "target_id": widget.peerId,
    }));
    setState(() => _state = _CallState.ended);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) Navigator.pop(context);
    });
  }

  void _endCall() {
    _channel?.sink.add(jsonEncode({
      "type": "call_end",
      "target_id": widget.peerId,
    }));
    _handleHangUp();
  }

  void _handleHangUp() {
    if (!mounted) return;
    setState(() => _state = _CallState.ended);
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) Navigator.pop(context);
    });
  }

  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || _state != _CallState.connected) return false;
      setState(() => _callDuration++);
      return true;
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _channel?.sink.close();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _primary.withValues(alpha: 0.15),
            _bg,
            _bg,
          ],
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 60),
          _buildCallTypeChip(),
          const SizedBox(height: 32),
          _buildAvatar(),
          const SizedBox(height: 20),
          Text(
            widget.peerUsername,
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _buildStatusText(),
          const Spacer(),
          _buildControls(),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildCallTypeChip() {
    final icon = widget.callType == "video" ? Icons.videocam_rounded : Icons.call_rounded;
    final label = widget.callType == "video" ? "Video Call" : "Voice Call";
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: _primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _primary, size: 16),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: _primary, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    Widget avatar;
    final avatarUrl = widget.peerAvatarUrl;
    if (avatarUrl != null && avatarUrl.startsWith('data:')) {
      try {
        final bytes = base64Decode(avatarUrl.split(',')[1]);
        avatar = CircleAvatar(radius: 60, backgroundImage: MemoryImage(bytes));
      } catch (_) {
        avatar = _initialsAvatar(60);
      }
    } else if (avatarUrl != null && avatarUrl.isNotEmpty) {
      avatar = CircleAvatar(radius: 60, backgroundImage: NetworkImage(avatarUrl));
    } else {
      avatar = _initialsAvatar(60);
    }

    if (_state == _CallState.calling || _state == _CallState.ringing) {
      return AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, child) => Transform.scale(scale: _pulseAnim.value, child: child),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: _primary.withValues(alpha: 0.4), blurRadius: 30, spreadRadius: 10)],
          ),
          child: avatar,
        ),
      );
    }
    return avatar;
  }

  Widget _initialsAvatar(double radius) {
    const colors = [Color(0xFF7C5CF6), Color(0xFF2E82FF), Color(0xFFEC4899), Color(0xFF10B981)];
    final color = colors[widget.peerUsername.hashCode.abs() % colors.length];
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.25),
      child: Text(
        widget.peerUsername.isNotEmpty ? widget.peerUsername[0].toUpperCase() : "?",
        style: TextStyle(color: color, fontSize: radius * 0.6, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildStatusText() {
    String text;
    Color color;
    switch (_state) {
      case _CallState.ringing:
        text = widget.isIncoming ? "Incoming ${widget.callType} call…" : "Ringing…";
        color = _textSecondary;
        break;
      case _CallState.calling:
        text = "Calling…";
        color = _textSecondary;
        break;
      case _CallState.connected:
        text = _formatDuration(_callDuration);
        color = _online;
        break;
      case _CallState.ended:
        text = "Call ended";
        color = _danger;
        break;
    }
    return Text(text, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w500));
  }

  Widget _buildControls() {
    if (_state == _CallState.ringing && widget.isIncoming) {
      return _buildIncomingControls();
    }
    if (_state == _CallState.connected) {
      return _buildInCallControls();
    }
    if (_state == _CallState.calling) {
      return _buildCallingControls();
    }
    return const SizedBox.shrink();
  }

  Widget _buildIncomingControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _circleButton(Icons.call_end_rounded, _danger, "Decline", _rejectCall),
        _circleButton(Icons.call_rounded, _online, "Accept", _acceptCall),
      ],
    );
  }

  Widget _buildCallingControls() {
    return Column(
      children: [
        _circleButton(Icons.call_end_rounded, _danger, "Cancel", _endCall),
      ],
    );
  }

  Widget _buildInCallControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _circleButton(
          _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
          _muted ? _textSecondary : _surface,
          _muted ? "Unmute" : "Mute",
          () => setState(() => _muted = !_muted),
          iconColor: _muted ? Colors.white : Colors.white,
          border: true,
        ),
        _circleButton(Icons.call_end_rounded, _danger, "End", _endCall),
        if (widget.callType == "video")
          _circleButton(
            _cameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
            _cameraOff ? _textSecondary : _surface,
            _cameraOff ? "Cam On" : "Cam Off",
            () => setState(() => _cameraOff = !_cameraOff),
            iconColor: Colors.white,
            border: true,
          )
        else
          _circleButton(Icons.speaker_phone_rounded, _surface, "Speaker", () {}, iconColor: Colors.white, border: true),
      ],
    );
  }

  Widget _circleButton(
    IconData icon,
    Color bgColor,
    String label,
    VoidCallback onTap, {
    Color iconColor = Colors.white,
    bool border = false,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: border ? Border.all(color: _textSecondary.withValues(alpha: 0.3), width: 1.5) : null,
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: _textSecondary, fontSize: 12)),
      ],
    );
  }
}
