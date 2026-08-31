import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _emailController = TextEditingController(text: '');
  final _passwordController = TextEditingController(text: '');
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Lamp & Cord interactive animation state
  late final AnimationController _lampController;
  late final AnimationController _springController;
  late Animation<double> _springAnimation;
  bool _isLightOn = true;
  double _dragOffset = 0.0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();

    // Auto-turn on lamp over 1.2s on screen open
    _lampController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Spring controller for cord release
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _springAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _springController, curve: Curves.elasticOut),
    );

    // Start auto lamp turn on
    _lampController.forward();
  }

  @override
  void dispose() {
    _lampController.dispose();
    _springController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onCordDragUpdate(DragUpdateDetails details) {
    setState(() {
      _isDragging = true;
      _dragOffset = (_dragOffset + details.delta.dy).clamp(0.0, 60.0);
    });
  }

  void _onCordDragEnd(DragEndDetails details) {
    final releaseStart = _dragOffset;
    if (releaseStart > 25.0) {
      // Toggle light state
      setState(() {
        _isLightOn = !_isLightOn;
      });
      if (_isLightOn) {
        _lampController.animateTo(1.0, duration: const Duration(milliseconds: 500), curve: Curves.easeOut);
      } else {
        _lampController.animateTo(0.0, duration: const Duration(milliseconds: 500), curve: Curves.easeOut);
      }
    }

    _springAnimation = Tween<double>(begin: releaseStart, end: 0.0).animate(
      CurvedAnimation(parent: _springController, curve: Curves.elasticOut),
    );

    _isDragging = false;
    _dragOffset = 0.0;
    _springController.reset();
    _springController.forward();
  }

  void _handleStandardLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both email and password.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authRes = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (authRes.user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login failed: Authentication returned no user.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final realEmail = authRes.user!.email ?? email;
      final res = await Supabase.instance.client
          .from('roles')
          .select('*')
          .eq('email', realEmail)
          .maybeSingle();

      if (res == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No role assigned to this user.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final String dbRole = res['role'].toString().toUpperCase();
      final String realName = (res['full_name'] ?? res['name'] ?? realEmail).toString();
      final authService = AuthService();

      switch (dbRole) {
        case 'SUPER_ADMIN':
        case 'SUPERADMIN':
          authService.loginAsSuperAdmin(email: realEmail, name: realName);
          break;
        case 'CEO':
          authService.loginAsCeo(email: realEmail, name: realName);
          break;
        case 'HR':
          authService.loginAsHr(email: realEmail, name: realName);
          break;
        case 'WAREHOUSE_PICKER':
        case 'PICKER':
          authService.loginAsWarehousePicker(email: realEmail, name: realName);
          break;
        case 'STOREKEEPER':
          authService.loginAsStorekeeper(email: realEmail, name: realName);
          break;
        case 'CATALOG_ADMIN':
        case 'CATALOG':
          authService.loginAsCatalogAdmin(email: realEmail, name: realName);
          break;
        case 'BRANCH_MANAGER':
        case 'MANAGER':
          authService.loginAsBranchManager(email: realEmail, name: realName);
          break;
        case 'TELESALES':
          authService.loginAsTelesales(email: realEmail, name: realName);
          break;
        case 'SECRETARY':
          authService.loginAsSecretary(email: realEmail, name: realName);
          break;
        case 'RIDER':
          authService.loginAsRider(email: realEmail, name: realName);
          break;
        case 'MARKETER':
          authService.loginAsMarketer(email: realEmail, name: realName);
          break;
        default:
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Unknown role in database.'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            children: [
              // Lamp & Cord Header
              AnimatedBuilder(
                animation: Listenable.merge([_lampController, _springController]),
                builder: (context, _) {
                  final brightness = _lampController.value;
                  final cordOffset = _isDragging ? _dragOffset : _springAnimation.value;

                  return Column(
                    children: [
                      SizedBox(
                        height: 180,
                        width: 320,
                        child: Stack(
                          alignment: Alignment.topCenter,
                          children: [
                            // Lamp Painting (Beam, Shade, Bulb, Cord)
                            CustomPaint(
                              size: const Size(320, 180),
                              painter: _PullCordLampPainter(
                                brightness: brightness,
                                cordOffset: cordOffset,
                              ),
                            ),
                            // Interactive Cord Touch Target
                            Positioned(
                              top: 76 + 50 + cordOffset - 12,
                              left: (320 / 2) + 26 - 20,
                              child: GestureDetector(
                                onVerticalDragUpdate: _onCordDragUpdate,
                                onVerticalDragEnd: _onCordDragEnd,
                                behavior: HitTestBehavior.opaque,
                                child: Container(
                                  width: 40,
                                  height: 44,
                                  color: Colors.transparent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      // First-run hint
                      Text(
                        'Pull the cord',
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 20),

              // Enterprise Pharmacy Brand Header
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: const Icon(
                    Icons.local_pharmacy_rounded,
                    color: Color(0xFF10B981),
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Multi-Tenant Enterprise ERP',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Wholesale B2B SaaS • Authentication Gateway',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF10B981),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),

              // Login Form Card
              Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF334155)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Corporate Email
                      Text(
                        'Corporate Email',
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF10B981), size: 20),
                          hintText: 'Enter your corporate email',
                          hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 13),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF334155)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF334155)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Password
                      Text(
                        'Password',
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) => _isLoading ? null : _handleStandardLogin(),
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF10B981), size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: Colors.white54,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                          ),
                          hintText: '••••••••',
                          hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 13),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF334155)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF334155)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Sign In Button
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleStandardLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: const Color(0xFF0F172A),
                          disabledBackgroundColor: const Color(0xFF10B981).withValues(alpha: 0.4),
                          disabledForegroundColor: Colors.white54,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF0F172A)),
                              )
                            : Text(
                                'Sign In to Enterprise Workspace',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter for the pull-cord lamp, emerald glow, light beam, and elastic spring cord
class _PullCordLampPainter extends CustomPainter {
  final double brightness;
  final double cordOffset;

  _PullCordLampPainter({
    required this.brightness,
    required this.cordOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;

    // 1. Light Beam Cone (When Lamp is ON)
    if (brightness > 0.001) {
      final beamPath = Path()
        ..moveTo(centerX - 46, 76)
        ..lineTo(centerX + 46, 76)
        ..lineTo(centerX + 130, size.height)
        ..lineTo(centerX - 130, size.height)
        ..close();

      final beamPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF10B981).withValues(alpha: 0.22 * brightness),
            const Color(0xFF10B981).withValues(alpha: 0.06 * brightness),
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromLTRB(centerX - 130, 76, centerX + 130, size.height));

      canvas.drawPath(beamPath, beamPaint);

      // Bulb Radial Glow
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF10B981).withValues(alpha: 0.50 * brightness),
            const Color(0xFF10B981).withValues(alpha: 0.15 * brightness),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(centerX, 76), radius: 55));

      canvas.drawCircle(Offset(centerX, 76), 55, glowPaint);
    }

    // 2. Ceiling Mount
    final mountPaint = Paint()
      ..color = const Color(0xFF334155)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(centerX, 4), width: 38, height: 6),
        const Radius.circular(3),
      ),
      mountPaint,
    );

    // 3. Hanging Stem
    final stemPaint = Paint()
      ..color = const Color(0xFF475569)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(centerX, 6), Offset(centerX, 32), stemPaint);

    // 4. Bulb
    final bulbPaint = Paint()
      ..color = Color.lerp(const Color(0xFF334155), const Color(0xFFF1F5F9), brightness)!
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(centerX, 74), 10, bulbPaint);

    // 5. Lamp Shade (Trapezoid)
    final shadePath = Path()
      ..moveTo(centerX - 22, 32)
      ..lineTo(centerX + 22, 32)
      ..lineTo(centerX + 50, 74)
      ..lineTo(centerX - 50, 74)
      ..close();

    final shadePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF334155), Color(0xFF1E293B)],
      ).createShader(Rect.fromLTRB(centerX - 50, 32, centerX + 50, 74))
      ..style = PaintingStyle.fill;

    canvas.drawPath(shadePath, shadePaint);

    // Shade Border & Trim
    final borderPaint = Paint()
      ..color = const Color(0xFF475569)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(shadePath, borderPaint);

    // Emerald Bottom Rim Trim
    final rimPaint = Paint()
      ..color = Color.lerp(const Color(0xFF475569), const Color(0xFF10B981), brightness)!
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(centerX - 50, 74), Offset(centerX + 50, 74), rimPaint);

    // 6. Pull Cord String
    const double cordStartX = 26.0;
    final double cordOriginX = centerX + cordStartX;
    const double cordOriginY = 74.0;
    final double cordEndY = cordOriginY + 50.0 + cordOffset;

    final cordPaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(cordOriginX, cordOriginY), Offset(cordOriginX, cordEndY), cordPaint);

    // 7. Pull Knob Handle (Bead)
    final knobCenter = Offset(cordOriginX, cordEndY + 7.0);

    // Glow on knob if dragging
    if (cordOffset > 5.0) {
      final knobGlow = Paint()
        ..color = const Color(0xFF10B981).withValues(alpha: 0.4)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(knobCenter, 11.0, knobGlow);
    }

    final knobPaint = Paint()
      ..color = Color.lerp(const Color(0xFF64748B), const Color(0xFF10B981), brightness)!
      ..style = PaintingStyle.fill;
    canvas.drawCircle(knobCenter, 6.5, knobPaint);

    final knobBorder = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(knobCenter, 6.5, knobBorder);
  }

  @override
  bool shouldRepaint(covariant _PullCordLampPainter oldDelegate) {
    return oldDelegate.brightness != brightness || oldDelegate.cordOffset != cordOffset;
  }
}

