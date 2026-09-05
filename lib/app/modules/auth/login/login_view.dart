import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../utils/app_theme.dart';
import 'login_controller.dart';

class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FA),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = kIsWeb && constraints.maxWidth >= 980;
            return desktop
                ? _DesktopLoginExperience(controller: controller)
                : _MobileLoginExperience(controller: controller);
          },
        ),
      ),
    );
  }
}

class _DesktopLoginExperience extends StatelessWidget {
  const _DesktopLoginExperience({required this.controller});

  final LoginController controller;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: _BrandBackground()),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 38, vertical: 34),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFFEAE7ED)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3C1730).withValues(alpha: .10),
                      blurRadius: 42,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    const _DesktopBrandHeader(),
                    Container(height: 1, color: const Color(0xFFEEEAF0)),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Expanded(
                            flex: 12,
                            child: _BusinessStoryPanel(),
                          ),
                          Container(width: 1, color: const Color(0xFFEEEAF0)),
                          Expanded(
                            flex: 10,
                            child: Container(
                              color: const Color(0xFFFCFAFC),
                              padding: const EdgeInsets.fromLTRB(
                                48,
                                42,
                                48,
                                46,
                              ),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 430,
                                  ),
                                  child: _LoginForm(controller: controller),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MobileLoginExperience extends StatelessWidget {
  const _MobileLoginExperience({required this.controller});

  final LoginController controller;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: _BrandBackground()),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  const _MobileBrandHero(),
                  Transform.translate(
                    offset: const Offset(0, -18),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: const Color(0xFFEAE7ED)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF3C1730,
                            ).withValues(alpha: .10),
                            blurRadius: 28,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: _LoginForm(controller: controller),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'BIOFARMA S.A. · SIGMA Corp. · SIGPRED 2026',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: SigmaColors.muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BrandBackground extends StatelessWidget {
  const _BrandBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFFBFD), Color(0xFFF5F6FA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -150,
            right: -90,
            child: _SoftOrb(
              size: 330,
              color: SigmaColors.primary.withValues(alpha: .075),
            ),
          ),
          Positioned(
            bottom: -180,
            left: -120,
            child: _SoftOrb(
              size: 390,
              color: SigmaColors.secondary.withValues(alpha: .055),
            ),
          ),
          Positioned(
            top: 80,
            left: 70,
            child: _DotMatrix(
              color: SigmaColors.primary.withValues(alpha: .12),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftOrb extends StatelessWidget {
  const _SoftOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _DotMatrix extends StatelessWidget {
  const _DotMatrix({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 86,
      child: Wrap(
        spacing: 9,
        runSpacing: 9,
        children: List.generate(
          20,
          (_) => Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

class _DesktopBrandHeader extends StatelessWidget {
  const _DesktopBrandHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 38, vertical: 20),
      child: Row(
        children: [
          const _CompanyLogo(width: 196, height: 72),
          const SizedBox(width: 22),
          Container(width: 1, height: 48, color: const Color(0xFFE8E4EA)),
          const SizedBox(width: 22),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SIGPRED',
                  style: TextStyle(
                    color: SigmaColors.ink,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .5,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Visita médica conectada a resultados de ventas',
                  style: TextStyle(
                    color: SigmaColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const _SecurityBadge(),
        ],
      ),
    );
  }
}

class _BusinessStoryPanel extends StatelessWidget {
  const _BusinessStoryPanel();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 42, 44, 46),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionEyebrow(label: 'PLATAFORMA DE VENTAS SIGMA'),
          const SizedBox(height: 16),
          Text(
            'De la visita médica a una decisión de ventas mejor informada.',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: SigmaColors.ink,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'SIGPRED integra la planificación del visitador, el registro de la visita, los pedidos y el análisis de ventas en un mismo flujo de trabajo.',
            style: TextStyle(
              color: SigmaColors.muted,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 30),
          const _ProcessRail(),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SigmaColors.primary.withValues(alpha: .045),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: SigmaColors.primary.withValues(alpha: .12),
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.verified_rounded,
                  color: SigmaColors.primary,
                  size: 21,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Regla de efectividad: con pedido la visita es efectiva; sin pedido es no efectiva.',
                    style: TextStyle(
                      color: SigmaColors.ink,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProcessRail extends StatelessWidget {
  const _ProcessRail();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.route_rounded, '01', 'Planifica', 'Ruta y clientes del día'),
      (Icons.badge_outlined, '02', 'Visita', 'Actividad médica en campo'),
      (
        Icons.shopping_bag_outlined,
        '03',
        'Concreta',
        'Pedido y venta registrada',
      ),
      (Icons.auto_graph_rounded, '04', 'Anticipa', 'Pronóstico de ventas'),
    ];

    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          _ProcessStep(
            icon: items[i].$1,
            number: items[i].$2,
            title: items[i].$3,
            subtitle: items[i].$4,
          ),
          if (i < items.length - 1)
            const Padding(
              padding: EdgeInsets.only(left: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  height: 18,
                  child: VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: Color(0xFFE5DFE7),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _ProcessStep extends StatelessWidget {
  const _ProcessStep({
    required this.icon,
    required this.number,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String number;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: SigmaColors.primary.withValues(alpha: .09),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: SigmaColors.primary, size: 21),
        ),
        const SizedBox(width: 13),
        SizedBox(
          width: 30,
          child: Text(
            number,
            style: const TextStyle(
              color: SigmaColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: SigmaColors.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: SigmaColors.muted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MobileBrandHero extends StatelessWidget {
  const _MobileBrandHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 38),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE0007A), Color(0xFF9B0055)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: SigmaColors.primary.withValues(alpha: .18),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -32,
            top: -42,
            child: Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            children: [
              const _CompanyLogo(width: 184, height: 76),
              const SizedBox(height: 16),
              const Text(
                'SIGPRED',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .7,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                kIsWeb
                    ? 'Acceso web para administración y supervisión de ventas'
                    : 'Tu jornada médica conectada a rutas, pedidos y resultados',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .88),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .15),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.route_outlined, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Visita  →  Pedido  →  Venta',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({required this.controller});

  final LoginController controller;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: controller.formkey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionEyebrow(label: 'ACCESO AL SISTEMA'),
          const SizedBox(height: 10),
          Text(
            kIsWeb
                ? 'Ingresa a tu espacio de trabajo'
                : 'Inicia tu jornada en SIGPRED',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: SigmaColors.ink,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Utiliza la cuenta asignada por SIGMA Corp. El sistema identifica tu rol y abre únicamente las funciones autorizadas.',
            style: const TextStyle(
              color: SigmaColors.muted,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          const _FieldLabel(label: 'Correo electrónico'),
          const SizedBox(height: 7),
          TextFormField(
            controller: controller.emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            style: const TextStyle(
              color: SigmaColors.ink,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            cursorColor: SigmaColors.primary,
            decoration: _loginInputDecoration(
              hint: 'nombre@empresa.com',
              icon: Icons.alternate_email_rounded,
            ),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return 'Ingresa tu correo electrónico.';
              if (!text.contains('@') || !text.contains('.')) {
                return 'Ingresa un correo válido.';
              }
              return null;
            },
          ),
          const SizedBox(height: 17),
          const _FieldLabel(label: 'Contraseña'),
          const SizedBox(height: 7),
          Obx(
            () => TextFormField(
              controller: controller.passCtrl,
              obscureText: controller.hidePassword.value,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              style: const TextStyle(
                color: SigmaColors.ink,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              cursorColor: SigmaColors.primary,
              onFieldSubmitted: (_) {
                if (!controller.isLoading.value) {
                  controller.onLoginPressed();
                }
              },
              decoration:
                  _loginInputDecoration(
                    hint: 'Ingresa tu contraseña',
                    icon: Icons.lock_outline_rounded,
                  ).copyWith(
                    suffixIcon: IconButton(
                      tooltip: controller.hidePassword.value
                          ? 'Mostrar contraseña'
                          : 'Ocultar contraseña',
                      onPressed: () => controller.hidePassword.value =
                          !controller.hidePassword.value,
                      icon: Icon(
                        controller.hidePassword.value
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
              validator: (value) {
                if ((value ?? '').isEmpty) return 'Ingresa tu contraseña.';
                if ((value ?? '').length < 6) {
                  return 'La contraseña debe tener al menos 6 caracteres.';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 22),
          Obx(
            () => SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: controller.isLoading.value
                    ? null
                    : controller.onLoginPressed,
                icon: controller.isLoading.value
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.arrow_forward_rounded),
                label: Text(
                  controller.isLoading.value
                      ? 'Ingresando...'
                      : 'Ingresar a SIGPRED',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: SigmaColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 17),
          const _RoleAccessInfo(),
        ],
      ),
    );
  }
}

class _RoleAccessInfo extends StatelessWidget {
  const _RoleAccessInfo();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7EAF0)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.admin_panel_settings_outlined,
            size: 19,
            color: SigmaColors.secondary,
          ),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'SIGPRED identifica tu perfil y muestra las funciones disponibles.',
              style: TextStyle(
                color: SigmaColors.muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompanyLogo extends StatelessWidget {
  const _CompanyLogo({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0E8EE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .075),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Image.asset(
        'assets/images/biofarma_sigma_logo.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Icon(
          Icons.business_rounded,
          color: SigmaColors.primary,
          size: 42,
        ),
      ),
    );
  }
}

class _SecurityBadge extends StatelessWidget {
  const _SecurityBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: SigmaColors.success.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: SigmaColors.success.withValues(alpha: .15)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            color: SigmaColors.success,
            size: 16,
          ),
          SizedBox(width: 6),
          Text(
            'Acceso según tu perfil',
            style: TextStyle(
              color: SigmaColors.success,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionEyebrow extends StatelessWidget {
  const _SectionEyebrow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: SigmaColors.primary,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.1,
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: SigmaColors.ink,
        fontSize: 12.5,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

InputDecoration _loginInputDecoration({
  required String hint,
  required IconData icon,
}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF7B808A)),
    prefixIcon: Icon(icon, color: SigmaColors.primary),
    suffixIconColor: SigmaColors.muted,
    filled: true,
    fillColor: const Color(0xFFFBFAFC),
    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 17),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFE1DDE3)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFE1DDE3)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: SigmaColors.primary, width: 1.8),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: SigmaColors.danger),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: SigmaColors.danger, width: 1.8),
    ),
  );
}
