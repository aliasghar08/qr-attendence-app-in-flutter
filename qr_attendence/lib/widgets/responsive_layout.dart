import 'package:flutter/material.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final double tabletBreakpoint;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.tabletBreakpoint = 720.0,
  });

  static bool isTablet(BuildContext context, {double breakpoint = 720.0}) {
    return MediaQuery.sizeOf(context).width >= breakpoint;
  }

  static bool isLandscape(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.width > size.height;
  }

  static int gridColumns(
    BuildContext context, {
    int mobile = 1,
    int tablet = 2,
    int desktop = 3,
    double breakpoint = 720.0,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1100) return desktop;
    if (width >= breakpoint) return tablet;
    return mobile;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= tabletBreakpoint && tablet != null) {
          return tablet!;
        }
        return mobile;
      },
    );
  }
}

class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxContentWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxContentWidth = 1100.0,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isTab = ResponsiveLayout.isTablet(context);
    final defaultPadding = EdgeInsets.symmetric(
      horizontal: isTab ? 32.0 : 20.0,
      vertical: isTab ? 24.0 : 16.0,
    );

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxContentWidth),
        child: Padding(
          padding: padding ?? defaultPadding,
          child: child,
        ),
      ),
    );
  }
}

class AdaptiveTwoPaneLayout extends StatelessWidget {
  final Widget leftPane;
  final Widget rightPane;
  final int leftFlex;
  final int rightFlex;
  final double spacing;
  final double breakpoint;

  const AdaptiveTwoPaneLayout({
    super.key,
    required this.leftPane,
    required this.rightPane,
    this.leftFlex = 1,
    this.rightFlex = 1,
    this.spacing = 24.0,
    this.breakpoint = 760.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= breakpoint) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: leftFlex,
                child: leftPane,
              ),
              SizedBox(width: spacing),
              Expanded(
                flex: rightFlex,
                child: rightPane,
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            leftPane,
            SizedBox(height: spacing),
            rightPane,
          ],
        );
      },
    );
  }
}
