#define Pi 3.14159265359
#define I3 float3x3(1, 0, 0, 0, 1, 0, 0, 0, 1)
#define I4 float4x4(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)

static const float cdel6O2KO[7] = { 0.015625, -0.09375, 0.234375, -0.3125, 0.234375, -0.09375, 0.015625 };

static const float cdel5O2[49] = { -3.50000000, 20.00000000, -47.50000000, 60.00000000, -42.50000000, 16.00000000, -2.50000000, -2.50000000, 14.00000000, -32.50000000, 40.00000000, -27.50000000, 10.00000000, -1.50000000, -1.50000000, 8.00000000, -17.50000000, 20.00000000, -12.50000000, 4.00000000, -0.50000000, -0.50000000, 2.00000000, -2.50000000, 0.00000000, 2.50000000, -2.00000000, 0.50000000, 0.50000000, -4.00000000, 12.50000000, -20.00000000, 17.50000000, -8.00000000, 1.50000000, 1.50000000, -10.00000000, 27.50000000, -40.00000000, 32.50000000, -14.00000000, 2.50000000, 2.50000000, -16.00000000, 42.50000000, -60.00000000, 47.50000000, -20.00000000, 3.50000000 };

static const float cdel4O4[49] = { 5.83333333, -31.00000000, 68.50000000, -80.66666667, 53.50000000, -19.00000000, 2.83333333, 2.83333333, -14.00000000, 28.50000000, -30.66666667, 18.50000000, -6.00000000, 0.83333333, 0.83333333, -3.00000000, 3.50000000, -0.66666667, -1.50000000, 1.00000000, -0.16666667, -0.16666667, 2.00000000, -6.50000000, 9.33333333, -6.50000000, 2.00000000, -0.16666667, -0.16666667, 1.00000000, -1.50000000, -0.66666667, 3.50000000, -3.00000000, 0.83333333, 0.83333333, -6.00000000, 18.50000000, -30.66666667, 28.50000000, -14.00000000, 2.83333333, 2.83333333, -19.00000000, 53.50000000, -80.66666667, 68.50000000, -31.00000000, 5.83333333 };

static const float cdel3O4[49] = { -6.12500000, 29.00000000, -57.62500000, 62.00000000, -38.37500000, 13.00000000, -1.87500000, -1.87500000, 7.00000000, -10.37500000, 8.00000000, -3.62500000, 1.00000000, -0.12500000, -0.12500000, -1.00000000, 4.37500000, -6.00000000, 3.62500000, -1.00000000, 0.12500000, 0.12500000, -1.00000000, 1.62500000, -0.00000000, -1.62500000, 1.00000000, -0.12500000, -0.12500000, 1.00000000, -3.62500000, 6.00000000, -4.37500000, 1.00000000, 0.12500000, 0.12500000, -1.00000000, 3.62500000, -8.00000000, 10.37500000, -7.00000000, 1.87500000, 1.87500000, -13.00000000, 38.37500000, -62.00000000, 57.62500000, -29.00000000, 6.12500000 };

static const float cdel2O6[49] = { 4.51111111, -17.40000000, 29.25000000, -28.22222222, 16.50000000, -5.40000000, 0.76111111, 0.76111111, -0.81666667, -1.41666667, 2.61111111, -1.58333333, 0.51666667, -0.07222222, -0.07222222, 1.26666667, -2.33333333, 1.11111111, 0.08333333, -0.06666667, 0.01111111, 0.01111111, -0.15000000, 1.50000000, -2.72222222, 1.50000000, -0.15000000, 0.01111111, 0.01111111, -0.06666667, 0.08333333, 1.11111111, -2.33333333, 1.26666667, -0.07222222, -0.07222222, 0.51666667, -1.58333333, 2.61111111, -1.41666667, -0.81666667, 0.76111111, 0.76111111, -5.40000000, 16.50000000, -28.22222222, 29.25000000, -17.40000000, 4.51111111 };

static const float cdelO6[49] = { -2.45000000, 6.00000000, -7.50000000, 6.66666667, -3.75000000, 1.20000000, -0.16666667, -0.16666667, -1.28333333, 2.50000000, -1.66666667, 0.83333333, -0.25000000, 0.03333333, 0.03333333, -0.40000000, -0.58333333, 1.33333333, -0.50000000, 0.13333333, -0.01666667, -0.01666667, 0.15000000, -0.75000000, 0.00000000, 0.75000000, -0.15000000, 0.01666667, 0.01666667, -0.13333333, 0.50000000, -1.33333333, 0.58333333, 0.40000000, -0.03333333, -0.03333333, 0.25000000, -0.83333333, 1.66666667, -2.50000000, 1.28333333, 0.16666667, 0.16666667, -1.20000000, 3.75000000, -6.66666667, 7.50000000, -6.00000000, 2.45000000 };

static const float cdel201[3] = { 1, -2, 1 };

static float FifthDerivative(int i, int pos, int resolution)
{
    pos -= clamp(pos - 3, 0, resolution - 7);
    return cdel5O2[clamp(i + 3, 0, 6) + pos * 7];
}
static float FourthDerivative(int i, int pos, int resolution)
{
    pos -= clamp(pos - 3, 0, resolution - 7);
    return cdel4O4[clamp(i + 3, 0, 6) + pos * 7];
}
static float ThirdDerivative(int i, int pos, int resolution)
{
    pos -= clamp(pos - 3, 0, resolution - 7);
    return cdel3O4[clamp(i + 3, 0, 6) + pos * 7];
}
static float SecondDerivative(int i, int pos, int resolution)
{
    pos -= clamp(pos - 3, 0, resolution - 7);
    return cdel2O6[clamp(i + 3, 0, 6) + pos * 7];
}
static float FirstDerivative(int i, int pos, int resolution)
{
    pos -= clamp(pos - 3, 0, resolution - 7);
    return cdelO6[clamp(i + 3, 0, 6) + pos * 7];
}

static const float3x3 LC1 = float3x3(0, 0, 0, 0, 0, 1, 0, -1, 0);
static const float3x3 LC2 = float3x3(0, 0, -1, 0, 0, 0, 1, 0, 0);
static const float3x3 LC3 = float3x3(0, 1, 0, -1, 0, 0, 0, 0, 0);

float3x3 matInvSymUD(float3x3 m)
{
    float m11 = m._22 * m._33 - m._23 * m._32;
    float m12 = m._13 * m._32 - m._12 * m._33;
    float m13 = m._12 * m._23 - m._13 * m._22;
    float m22 = m._11 * m._33 - m._13 * m._31;
    float m23 = m._13 * m._21 - m._11 * m._23;
    float m33 = m._11 * m._22 - m._12 * m._21;
    float3x3 mat = float3x3(m11, m12, m13, m12, m22, m23, m13, m23, m33);
    return mat;
}
float4x4 matInvFull(float4x4 m)
{
    float m11 = determinant(float3x3(m[1].yzw, m[2].yzw, m[3].yzw));
    float m12 = determinant(float3x3(m[0].yzw, m[2].yzw, m[3].yzw));
    float m13 = determinant(float3x3(m[0].yzw, m[1].yzw, m[3].yzw));
    float m14 = determinant(float3x3(m[0].yzw, m[1].yzw, m[2].yzw));
    float m21 = determinant(float3x3(m[1].xzw, m[2].xzw, m[3].xzw));
    float m22 = determinant(float3x3(m[0].xzw, m[2].xzw, m[3].xzw));
    float m23 = determinant(float3x3(m[0].xzw, m[1].xzw, m[3].xzw));
    float m24 = determinant(float3x3(m[0].xzw, m[1].xzw, m[2].xzw));
    float m31 = determinant(float3x3(m[1].xyw, m[2].xyw, m[3].xyw));
    float m32 = determinant(float3x3(m[0].xyw, m[2].xyw, m[3].xyw));
    float m33 = determinant(float3x3(m[0].xyw, m[1].xyw, m[3].xyw));
    float m34 = determinant(float3x3(m[0].xyw, m[1].xyw, m[2].xyw));
    float m41 = determinant(float3x3(m[1].xyz, m[2].xyz, m[3].xyz));
    float m42 = determinant(float3x3(m[0].xyz, m[2].xyz, m[3].xyz));
    float m43 = determinant(float3x3(m[0].xyz, m[1].xyz, m[3].xyz));
    float m44 = determinant(float3x3(m[0].xyz, m[1].xyz, m[2].xyz));
    float4x4 mat = float4x4(m11, -m12, m13, -m14, -m21, m22, -m23, m24, m31, -m32, m33, -m34, -m41, m42, -m43, m44);
    return transpose(mat) / determinant(m);
}
float Trace(float3x3 tensor)
{
    return tensor[0][0] + tensor[1][1] + tensor[2][2];
}
float Trace(float3x3 tensor, float3x3 invMetric)
{
    return Trace(mul(tensor, transpose(invMetric)));
}
float3x3 TraceFree(float3x3 tensor, float3x3 metric, float3x3 invMetric)
{
    return tensor - (0.3333333333333 * Trace(tensor, invMetric)) * metric;
}
float3x3 TraceFree(float3x3 tensor, float3x3 metric)
{
    return TraceFree(tensor, metric, matInvSymUD(metric));
}
float3x3 TensorProduct(float3 a, float3 b)
{
    float3x3 result = 0;
    for (int i = 0; i < 3; i++)
        result[i] = a[i] * b;
    return result;
}
float4x4 TensorProduct(float4 a, float4 b)
{
    float4x4 result = 0;
    for (int i = 0; i < 4; i++)
        result[i] = a[i] * b;
    return result;
}

float3x3 ContractBoth(float3x3 tensor, float3x3 metric)
{
    return mul(mul(metric, tensor), metric);
}
float3x3 Symmetrize(float3x3 tensor)
{
    return (tensor + transpose(tensor)) * .5;
}
float SelfTraceSymmetric(float3x3 tensor, float3x3 invMetric)
{
    tensor = mul(invMetric, tensor);
    return Trace(mul(tensor, tensor));
}

float3x3 PermuteOuterIndexContract(float3x3 tensor1, float3x3 tensor2)
{
    return Symmetrize(mul(tensor2, tensor1));
}
float3x3 PermutedTensorProduct(float3 a, float3 b)
{
    return Symmetrize(TensorProduct(a, b));
}
int4 RNG(int4 seed)
{
    seed *= mad(seed.yxwz, seed.xzyw, int4(1528953289, -2787578, 832958327, 1218957328));
    seed ^= mad(seed.yxwz, int4(1528953289, -1218957328, -156745233, 832958327), seed.xzyw);
    return mad(seed, int4(1748127, -581928478, 1784412, 1247858945), int4(-1528953289, 1218957328, -156745233, -832958327));
}
float4 RNGV4(int4 seed)
{
    return float4(RNG(seed)) / 2147483648.;
}