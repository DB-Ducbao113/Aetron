import 'dart:math' as math;
import 'dart:typed_data';

import 'package:latlong2/latlong.dart';

/// Lightweight, zero-allocation friendly 4x4 matrix stored in row-major order:
/// [ m00, m01, m02, m03,
///   m10, m11, m12, m13,
///   m20, m21, m22, m23,
///   m30, m31, m32, m33 ]
class Matrix4x4 {
  final Float64List storage;

  Matrix4x4([Float64List? initial]) : storage = initial ?? Float64List(16);

  factory Matrix4x4.identity() {
    final m = Matrix4x4();
    m.storage[0] = 1.0;
    m.storage[5] = 1.0;
    m.storage[10] = 1.0;
    m.storage[15] = 1.0;
    return m;
  }

  factory Matrix4x4.diagonal(double d0, double d1, double d2, double d3) {
    final m = Matrix4x4();
    m.storage[0] = d0;
    m.storage[5] = d1;
    m.storage[10] = d2;
    m.storage[15] = d3;
    return m;
  }

  factory Matrix4x4.fromList(List<double> values) {
    assert(values.length == 16, 'Matrix4x4 requires 16 elements');
    final m = Matrix4x4();
    for (var i = 0; i < 16; i++) {
      m.storage[i] = values[i];
    }
    return m;
  }

  double get(int row, int col) => storage[row * 4 + col];
  void set(int row, int col, double val) => storage[row * 4 + col] = val;

  Matrix4x4 copy() {
    final out = Matrix4x4();
    out.storage.setAll(0, storage);
    return out;
  }

  Matrix4x4 operator +(Matrix4x4 other) {
    final out = Matrix4x4();
    for (var i = 0; i < 16; i++) {
      out.storage[i] = storage[i] + other.storage[i];
    }
    return out;
  }

  Matrix4x4 operator -(Matrix4x4 other) {
    final out = Matrix4x4();
    for (var i = 0; i < 16; i++) {
      out.storage[i] = storage[i] - other.storage[i];
    }
    return out;
  }

  Matrix4x4 operator *(Matrix4x4 other) {
    final out = Matrix4x4();
    for (var r = 0; r < 4; r++) {
      final rOffset = r * 4;
      for (var c = 0; c < 4; c++) {
        var sum = 0.0;
        for (var k = 0; k < 4; k++) {
          sum += storage[rOffset + k] * other.storage[k * 4 + c];
        }
        out.storage[rOffset + c] = sum;
      }
    }
    return out;
  }

  Float64List multiplyVector(Float64List v) {
    assert(v.length == 4);
    final out = Float64List(4);
    for (var r = 0; r < 4; r++) {
      final rOffset = r * 4;
      out[r] =
          storage[rOffset] * v[0] +
          storage[rOffset + 1] * v[1] +
          storage[rOffset + 2] * v[2] +
          storage[rOffset + 3] * v[3];
    }
    return out;
  }

  Matrix4x4 transpose() {
    final out = Matrix4x4();
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 4; c++) {
        out.storage[c * 4 + r] = storage[r * 4 + c];
      }
    }
    return out;
  }

  /// Enforces symmetry: P = 0.5 * (P + P^T), clamps diagonal variances >= minVariance,
  /// and applies Cauchy-Schwarz constraint |P_ij| <= 0.999 * sqrt(P_ii * P_jj)
  /// to ensure positive-definiteness and numerical stability across long tracking sessions.
  void symmetrizeAndClamp([double minVariance = 1e-4]) {
    // 1. Symmetrize off-diagonals
    for (var r = 0; r < 4; r++) {
      for (var c = r + 1; c < 4; c++) {
        final avg = (storage[r * 4 + c] + storage[c * 4 + r]) * 0.5;
        storage[r * 4 + c] = avg;
        storage[c * 4 + r] = avg;
      }
    }

    // 2. Clamp diagonal elements >= minVariance
    for (var i = 0; i < 4; i++) {
      final val = storage[i * 4 + i];
      if (!val.isFinite || val < minVariance) {
        storage[i * 4 + i] = minVariance;
      }
    }

    // 3. Cauchy-Schwarz clamping on off-diagonal covariances
    for (var r = 0; r < 4; r++) {
      final varR = storage[r * 4 + r];
      for (var c = r + 1; c < 4; c++) {
        final varC = storage[c * 4 + c];
        final maxCov = 0.999 * math.sqrt(varR * varC);
        final cov = storage[r * 4 + c];
        if (cov.abs() > maxCov) {
          final clampedCov = cov.clamp(-maxCov, maxCov);
          storage[r * 4 + c] = clampedCov;
          storage[c * 4 + r] = clampedCov;
        }
      }
    }
  }

  /// Inverts a 4x4 matrix using Gauss-Jordan elimination with partial pivoting.
  /// Throws [StateError] if the matrix is singular or near-singular.
  Matrix4x4 invert([double epsilon = 1e-12]) {
    final a = Float64List(16)..setAll(0, storage);
    final b = Matrix4x4.identity().storage;

    for (var col = 0; col < 4; col++) {
      // Find pivot
      var pivotRow = col;
      var maxVal = a[col * 4 + col].abs();
      for (var row = col + 1; row < 4; row++) {
        final val = a[row * 4 + col].abs();
        if (val > maxVal) {
          maxVal = val;
          pivotRow = row;
        }
      }

      if (maxVal < epsilon) {
        throw StateError('Matrix4x4 is singular or near-singular (pivot: $maxVal)');
      }

      // Swap rows in a and b
      if (pivotRow != col) {
        for (var c = 0; c < 4; c++) {
          final tempA = a[col * 4 + c];
          a[col * 4 + c] = a[pivotRow * 4 + c];
          a[pivotRow * 4 + c] = tempA;

          final tempB = b[col * 4 + c];
          b[col * 4 + c] = b[pivotRow * 4 + c];
          b[pivotRow * 4 + c] = tempB;
        }
      }

      // Scale pivot row to 1
      final pivot = a[col * 4 + col];
      final invPivot = 1.0 / pivot;
      for (var c = 0; c < 4; c++) {
        a[col * 4 + c] *= invPivot;
        b[col * 4 + c] *= invPivot;
      }

      // Eliminate other rows
      for (var row = 0; row < 4; row++) {
        if (row != col) {
          final factor = a[row * 4 + col];
          if (factor.abs() > 1e-15) {
            for (var c = 0; c < 4; c++) {
              a[row * 4 + c] -= factor * a[col * 4 + c];
              b[row * 4 + c] -= factor * b[col * 4 + c];
            }
          }
        }
      }
    }

    return Matrix4x4(b);
  }
}

/// Fast 2x2 matrix operations used for position measurement updates:
/// S = H P H^T + R (when H is 2x4 position selector)
class Matrix2x2 {
  final double m00, m01;
  final double m10, m11;

  const Matrix2x2(this.m00, this.m01, this.m10, this.m11);

  double get determinant => m00 * m11 - m01 * m10;

  Matrix2x2 invert([double epsilon = 1e-12]) {
    final det = determinant;
    if (det.abs() < epsilon) {
      throw StateError('Matrix2x2 is singular (det: $det)');
    }
    final invDet = 1.0 / det;
    return Matrix2x2(
      m11 * invDet,
      -m01 * invDet,
      -m10 * invDet,
      m00 * invDet,
    );
  }
}

/// Geometric projection between WGS84 (Lat, Lng) and local metric tangent plane (East, North)
class EquirectangularProjection {
  final LatLng origin;
  final double _latCos;

  static const double earthRadiusMeters = 6378137.0;
  static const double degToRad = math.pi / 180.0;
  static const double radToDeg = 180.0 / math.pi;

  EquirectangularProjection(this.origin)
      : _latCos = math.cos(origin.latitude * degToRad);

  /// Projects [point] to local metric plane relative to [origin]:
  /// returns `(xMeters (East), yMeters (North))`.
  (double, double) project(LatLng point) {
    final dLat = (point.latitude - origin.latitude) * degToRad;
    final dLng = (point.longitude - origin.longitude) * degToRad;

    final y = dLat * earthRadiusMeters;
    final x = dLng * earthRadiusMeters * _latCos;
    return (x, y);
  }

  /// Inverse projects local metric coordinates `(x, y)` back to [LatLng].
  LatLng unproject(double xEast, double yNorth) {
    final dLat = (yNorth / earthRadiusMeters) * radToDeg;
    final dLng = (_latCos.abs() > 1e-7)
        ? (xEast / (earthRadiusMeters * _latCos)) * radToDeg
        : 0.0;

    return LatLng(
      origin.latitude + dLat,
      origin.longitude + dLng,
    );
  }

  /// Normalizes angle in radians to [-pi, pi]
  static double normalizeAngleRad(double angleRad) {
    var a = angleRad % (2 * math.pi);
    if (a > math.pi) a -= 2 * math.pi;
    if (a < -math.pi) a += 2 * math.pi;
    return a;
  }

  /// Normalizes angle in degrees to [0, 360)
  static double normalizeAngleDeg(double angleDeg) {
    return (angleDeg % 360.0 + 360.0) % 360.0;
  }
}
