import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lablink/presentation/common/widgets/buttons/primary_button.dart';
import 'package:lablink/presentation/common/widgets/buttons/secondary_button.dart';
import 'package:lablink/presentation/common/widgets/buttons/danger_button.dart';
import 'package:lablink/presentation/common/widgets/buttons/ghost_button.dart';

void main() {
  group('Button Widgets', () {
    group('PrimaryButton', () {
      testWidgets('renders label correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PrimaryButton(
                label: 'Test Button',
                onPressed: () {},
              ),
            ),
          ),
        );

        expect(find.text('Test Button'), findsOneWidget);
      });

      testWidgets('calls onPressed when tapped', (WidgetTester tester) async {
        bool pressed = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PrimaryButton(
                label: 'Test Button',
                onPressed: () => pressed = true,
              ),
            ),
          ),
        );

        await tester.tap(find.byType(PrimaryButton));
        await tester.pump();

        expect(pressed, true);
      });

      testWidgets('shows loading state', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PrimaryButton(
                label: 'Test Button',
                isLoading: true,
              ),
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    group('SecondaryButton', () {
      testWidgets('renders with secondary styling', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SecondaryButton(
                label: 'Secondary',
                onPressed: () {},
              ),
            ),
          ),
        );

        expect(find.text('Secondary'), findsOneWidget);
      });
    });

    group('DangerButton', () {
      testWidgets('renders with danger styling', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DangerButton(
                label: 'Delete',
                onPressed: () {},
              ),
            ),
          ),
        );

        expect(find.text('Delete'), findsOneWidget);
      });
    });

    group('GhostButton', () {
      testWidgets('renders with ghost styling', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GhostButton(
                label: 'Cancel',
                onPressed: () {},
              ),
            ),
          ),
        );

        expect(find.text('Cancel'), findsOneWidget);
      });
    });
  });
}
