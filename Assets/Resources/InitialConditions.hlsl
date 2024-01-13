#include "BSSNHelp.hlsl"

//static const float mass1 = 4.83; // Bare Mass
//static const float mass2 = 4.83; // Bare Mass

//static const float3 position1 = float3(-32.57, 0, 0);
//static const float3 position2 = float3(32.57, 0, 0);
//static const float3 momentum1 = float3(0, -1.34, 0);
//static const float3 momentum2 = float3(0, 1.34, 0);
//static const float3 spin1 = float3(0, 0, 0);
//static const float3 spin2 = float3(0, 0, 0);

static const float mass1 = 1.764; // Bare Mass
static const float mass2 = 1.764; // Bare Mass

static const float3 position1 = float3(-29.66, 0, 0);
static const float3 position2 = float3(29.66, 0, 0);
static const float3 momentum1 = float3(0, -1.2616, 0);
static const float3 momentum2 = float3(0, 1.2616, 0);
static const float3 spin1 = float3(0, 0, 22.5);
static const float3 spin2 = float3(0, 0, 22.5);

void YieldBSSNCurvatures(float3x3 Kij, float3x3 cYij, float W, out float K, out Sfloat3x3 Aij)
{
    Kij *= W * W;
    K = Trace(Kij, matInvSymUD(cYij));
    Aij.Set(Kij - cYij * K * .33333333333333);
}
float3x3 YieldPhysicalExtrinsicCurvature(float3x3 cYij, float W, float K, float3x3 Aij)
{
    return (Aij + K * cYij * .33333333333333) / (W * W);
}

float3 AlcubierreShift(float3 positionOffset, float sharpness, float radius, float3 direction)
{
    float r = sqrt(dot(positionOffset, positionOffset) + .01);
    return (tanh(clamp(sharpness * (r + radius), -10., 10.)) - tanh(clamp(sharpness * (r - radius), -10., 10.))) * direction * .5 / tanh(clamp(sharpness * radius, 0., 10.));
}
float3x3 ExtrinsicCurvatureAlcubierre(float3 positionOffset, float sharpness, float radius, float3 direction)
{
    float3x3 delNi = 0;
    delNi[0] = (AlcubierreShift(positionOffset + float3(.5, 0, 0), sharpness, radius, direction) - AlcubierreShift(positionOffset - float3(.5, 0, 0), sharpness, radius, direction));
    delNi[1] = (AlcubierreShift(positionOffset + float3(0, .5, 0), sharpness, radius, direction) - AlcubierreShift(positionOffset - float3(0, .5, 0), sharpness, radius, direction));
    delNi[2] = (AlcubierreShift(positionOffset + float3(0, 0, .5), sharpness, radius, direction) - AlcubierreShift(positionOffset - float3(0, 0, .5), sharpness, radius, direction));
    return Symmetrize(delNi);
}

float3x3 BowenYorkExtrinsicCurvature(float3 radial, float3 linearMom, float3 spin)
{
    float r = max(length(radial), .001); radial /= r;
    float3x3 distortion = TensorProduct(radial, radial) - I3 * dot(radial, radial);
    float3x3 res = (PermutedTensorProduct(linearMom, radial) + 0.5 * dot(linearMom, radial) * distortion) / (r * r);
    return 3. * (res + PermutedTensorProduct(cross(spin, radial), radial * 2. / (r * r * r)));
}
float BowenYorkConformalFactor(float3 radial, float mass)
{
    return mass * 0.5 * rsqrt(max(0.001, dot(radial, radial) - lengthScale * lengthScale * .06));
}