import 'package:flutter/painting.dart';

/// Same buckets as Deutsch-A1 `core/time-of-day.ts`.
/// (Named DayPhase because Flutter already has TimeOfDay and DayPeriod.)
enum DayPhase { dawn, morning, midday, afternoon, evening, night }

DayPhase phaseForHour(int hour) {
  if (hour >= 5 && hour < 7) return DayPhase.dawn;
  if (hour >= 7 && hour < 11) return DayPhase.morning;
  if (hour >= 11 && hour < 15) return DayPhase.midday;
  if (hour >= 15 && hour < 18) return DayPhase.afternoon;
  if (hour >= 18 && hour < 21) return DayPhase.evening;
  return DayPhase.night;
}

/// Visual spec per phase, ported from time-of-day-background.scss.
class PhaseStyle {
  const PhaseStyle(this.colors, this.stops, this.sunAlign, this.sunColor, {this.sunSize = 220});
  final List<Color> colors;
  final List<double> stops;
  final Alignment sunAlign;
  final Color sunColor;
  final double sunSize;
}

const phaseStyles = <DayPhase, PhaseStyle>{
  DayPhase.dawn: PhaseStyle([Color(0xFFFFE3D3), Color(0xFFF7C6DE), Color(0xFFCDD8F5)], [0, .45, 1],
      Alignment(-0.78, 0.85), Color(0xE6FFB080)),
  DayPhase.morning: PhaseStyle([Color(0xFFFFF6DA), Color(0xFFD9ECFF), Color(0xFFEEF5FF)], [0, .6, 1],
      Alignment(-0.68, -0.72), Color(0xD9FFE082)),
  DayPhase.midday: PhaseStyle([Color(0xFFEAF6FF), Color(0xFFCFE9FF), Color(0xFFF4FAFF)], [0, .55, 1],
      Alignment(0, -0.95), Color(0xE6FFFADC)),
  DayPhase.afternoon: PhaseStyle([Color(0xFFFFE9BD), Color(0xFFFFD2A6), Color(0xFFCFE0FF)], [0, .45, 1],
      Alignment(0.72, -0.68), Color(0xD9FFC878)),
  DayPhase.evening: PhaseStyle([Color(0xFFFFB17A), Color(0xFFF16F95), Color(0xFF5B53A6)], [0, .45, 1],
      Alignment(0.78, 0.8), Color(0xD9FF786E)),
  DayPhase.night: PhaseStyle([Color(0xFF171A35), Color(0xFF232A5C), Color(0xFF0D0F21)], [0, .55, 1],
      Alignment(-0.62, -0.78), Color(0x8CD2DCFF), sunSize: 140),
};
