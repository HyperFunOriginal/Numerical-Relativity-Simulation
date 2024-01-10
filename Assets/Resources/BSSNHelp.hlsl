#include "GeneralRelativityBasics.hlsl"

struct KAWGiNiBiDerivatives
{
    // Stride 36 floats
    float3x3 delKAW;
    float3x3 delNi;
    float3x3 delGi;
    
    void YieldEmpty()
    {
        delKAW = 0;
        delNi = 0;
        delGi = 0;
    }
    
    void TermwiseMAD(KAWGiNiBiDerivatives v, float value)
    {
        if (value == 0)
            return;
        
        delKAW += v.delKAW * value;
        delNi += v.delNi * value;
        delGi += v.delGi * value;
    }
};
struct DerivedConstants
{
    // Stride 23 floats
    float3x3 W2DmDnA;
    float3x3 W2Rij;
    float3 Mi;
    float3 Gi;
    float H;
    float LaplW;
    
    void YieldEmpty()
    {
        W2DmDnA = 0;
        W2Rij = 0;
        Mi = 0;
        H = 0;
        LaplW = 0;
    }
    
    void TermwiseMAD(DerivedConstants v, float value)
    {
        if (value == 0)
            return;
        W2DmDnA += v.W2DmDnA * value;
        W2Rij += v.W2Rij * value;
        Mi += v.Mi * value;
        H += v.H * value;
        LaplW += v.LaplW * value;
    }
};
struct YijAijDerivatives
{
    // Stride 54 floats
    float3x3 delYij[3];
    float3x3 delAij[3];
    
    void YieldEmpty()
    {
        delYij[0] = 0;
        delAij[0] = 0;
        delYij[1] = 0;
        delAij[1] = 0;
        delYij[2] = 0;
        delAij[2] = 0;
    }
    
    void TermwiseMAD(YijAijDerivatives v, float value)
    {
        if (value == 0)
            return;
        delYij[0] += v.delYij[0] * value;
        delAij[0] += v.delAij[0] * value;
        delYij[1] += v.delYij[1] * value;
        delAij[1] += v.delAij[1] * value;
        delYij[2] += v.delYij[2] * value;
        delAij[2] += v.delAij[2] * value;
    }
};

struct Voxel
{
    // Stride 21 floats
    Sfloat3x3 cYij;
    Sfloat3x3 Aij;
    float3 Gi;
    float4 N;
    float W;
    float K;
    
    void Zero()
    {
        W = 0;
        K = 0;
        N = 0;
        Gi = 0;
        Aij.Zero();
        cYij.Zero();
    }
    void TermwiseMAD(Voxel v, float value)
    {
        if (value == 0)
            return;
        
        cYij.TermwiseMAD(v.cYij, value);
        Aij.TermwiseMAD(v.Aij, value);
        Gi += value * v.Gi;
        N += value * v.N;
        W += value * v.W;
        K += value * v.K;
    }
    float3x3 Yij()
    {
        return cYij.toF3x3() / (W * W);
    }
    float3x3 CYUij()
    {
        return matInvSymUD(cYij.toF3x3());
    }
};

struct CompScalarVectorDerivs
{
    // Stride 9 floats
    f3x3Comp delKAW;
    f3x3Comp delNi;
    f3x3Comp delGi;
    
    void Compress(KAWGiNiBiDerivatives og, int4 seed)
    {
        float4 v = RNGV4(seed);
        delKAW.Set(og.delKAW * float(v.x * .005 + 1.));
        delNi.Set(og.delNi   * float(v.y * .005 + 1.));
        delGi.Set(og.delGi   * float(v.z * .005 + 1.));
    }
    KAWGiNiBiDerivatives Decompress()
    {
        KAWGiNiBiDerivatives res;
        res.delKAW = delKAW.toF3x3();
        res.delGi = delGi.toF3x3();
        res.delNi = delNi.toF3x3();
        return res;
    }
};
struct CompDerivedConstants
{
    // Stride 9 floats
    Sf3x3Comp W2DmDnA;
    Sf3x3Comp W2Rij;
    f3Comp Mi;
    f3Comp Gi;
    float H;
    float LaplW;
    
    void Compress(DerivedConstants og)
    {
        W2DmDnA.Set(og.W2DmDnA);
        W2Rij.Set(og.W2Rij);
        Mi.Set(og.Mi);
        Gi.Set(og.Gi);
        H = og.H;
        LaplW = og.LaplW;
    }
    DerivedConstants Decompress()
    {
        DerivedConstants res;
        res.W2DmDnA = W2DmDnA.toF3x3();
        res.W2Rij = W2Rij.toF3x3();
        res.Mi = Mi.toF3();
        res.Gi = Gi.toF3();
        res.H = H;
        res.LaplW = LaplW;
        return res;
    }
};
struct CompTensorDerivs
{
    // Stride 12 floats
    Sf3x3Comp delYij[3];
    Sf3x3Comp delAij[3];
    
    void Compress(YijAijDerivatives og, int4 seed)
    {
        float4 v = RNGV4(seed);
        delYij[0].Set(og.delYij[0] * float(v.x * .005 + 1.));
        delAij[0].Set(og.delAij[0] * float(v.y * .005 + 1.));
        delYij[1].Set(og.delYij[1] * float(v.z * .005 + 1.));
        delAij[1].Set(og.delAij[1] * float(v.w * .005 + 1.));
        delYij[2].Set(og.delYij[2] * float(v.y * .005 + 1.));
        delAij[2].Set(og.delAij[2] * float(v.x * .005 + 1.));
    }
    
    YijAijDerivatives Decompress()
    {
        YijAijDerivatives res;
        res.delYij[0] = delYij[0].toF3x3();
        res.delAij[0] = delAij[0].toF3x3();
        res.delYij[1] = delYij[1].toF3x3();
        res.delAij[1] = delAij[1].toF3x3();
        res.delYij[2] = delYij[2].toF3x3();
        res.delAij[2] = delAij[2].toF3x3();
        return res;
    }
};

float3 VectorWeightedLieDerivative(float3x3 pdS, float3 lieFlow, float3x3 flowDerivatives, float3 vec)
{
    return mul(lieFlow, pdS) - mul(vec, flowDerivatives) + .6666666666666666 * Trace(flowDerivatives) * vec;
}
float3x3 TensorWeightedLieDerivative(float3x3 pdS[3], float3 lieFlow, float3x3 flowDerivatives, float3x3 coten)
{
    float3x3 deriv = lieFlow[0] * pdS[0] + lieFlow[1] * pdS[1] + lieFlow[2] * pdS[2];
    deriv += Symmetrize(mul(flowDerivatives, coten)) * 2.;
    return deriv - .6666666666666666 * Trace(flowDerivatives) * coten;
}

int IdxClamp(int3 coords)
{
    coords = clamp(coords, 0, resolution - 1);
    return coords.z * resolution * resolution + coords.y * resolution + coords.x;
}
int Idx(int3 coords)
{
    int3 clamped = clamp(coords, 0, resolution - 1) - coords;
    if (dot(clamped, clamped) != 0)
        return -1;
    return coords.z * resolution * resolution + coords.y * resolution + coords.x;
}
void AijConstraint(inout Sfloat3x3 Aij, float3x3 cYij)
{
    Aij.Set(TraceFree(Aij.toF3x3(), cYij));
}
void cYijConstraint(inout Sfloat3x3 cYij)
{
    cYij.Mul(pow(abs(determinant(cYij.toF3x3())), -.33333333333333));
}
void AijConstraint(inout float3x3 Aij, float3x3 cYij)
{
    Aij = TraceFree(Symmetrize(Aij), cYij);
}
void cYijConstraint(inout float3x3 cYij)
{
    cYij = Symmetrize(cYij);
    cYij *= pow(abs(determinant(cYij)), -.333333333333333);
}
float3 AnalyticGi(Christoffel c, float3x3 invMetric)
{
    return float3(Trace(c.mn[0], invMetric), Trace(c.mn[1], invMetric), Trace(c.mn[2], invMetric));
}

float3x3 CyijLaplacian(RWStructuredBuffer<CompTensorDerivs> derivs, float3x3 cYuij, int3 origin)
{
    YijAijDerivatives del;
    float3 ddx = 1. / CoordinateMetric(origin);
    int3 offset = origin - clamp(origin - 3, 0, resolution - 7);
    
    del.YieldEmpty();
    for (int j = 0; j < 7; j++)
        del.TermwiseMAD(derivs[Idx(int3(j + origin.x - offset.x, origin.y, origin.z))].Decompress(), cdelO6[j + offset.x * 7] * ddx.x);
    float3x3 result = cYuij[0][0] * del.delYij[0] + cYuij[0][1] * del.delYij[1] + cYuij[0][2] * del.delYij[2];
    
    del.YieldEmpty();
    for (j = 0; j < 7; j++)
        del.TermwiseMAD(derivs[Idx(int3(origin.x, j + origin.y - offset.y, origin.z))].Decompress(), cdelO6[j + offset.y * 7] * ddx.y);
    result += cYuij[1][0] * del.delYij[0] + cYuij[1][1] * del.delYij[1] + cYuij[1][2] * del.delYij[2];
    
    del.YieldEmpty();
    for (j = 0; j < 7; j++)
        del.TermwiseMAD(derivs[Idx(int3(origin.x, origin.y, j + origin.z - offset.z))].Decompress(), cdelO6[j + offset.z * 7] * ddx.z);
    return result + cYuij[2][0] * del.delYij[0] + cYuij[2][1] * del.delYij[1] + cYuij[2][2] * del.delYij[2];
}
float3x3 RicciWTensor(float3 delW, float3x3 CovDmCovDnW, float3x3 metricTensor, float W)
{
    float3x3 RijW = Trace(W * CovDmCovDnW - 2. * TensorProduct(delW, delW), matInvSymUD(metricTensor)) * metricTensor;
    return Symmetrize(RijW + CovDmCovDnW * W);
}
float3x3 ConformalRicciWTensor(float3x3 yijLaplacian, float3x3 delGi, float3x3 metricTensor, float3x3 YUij, Christoffel lowered, Christoffel upper)
{
    float3x3 result = PermuteOuterIndexContract(metricTensor, delGi);
    float3 analytic = AnalyticGi(upper, YUij);
    for (int i = 0; i < 3; i++)
        for (int j = 0; j < 3; j++)
        {
            float delta = dot(analytic, lowered.mn[i][j] + lowered.mn[j][i]) * .5;
            for (int m = 0; m < 3; m++)
                for (int n = 0; n < 3; n++)
                    for (int k = 0; k < 3; k++)
                        delta += YUij[m][n] * (upper.mn[k][m][i] * lowered.mn[j][k][n] + upper.mn[k][m][j] * lowered.mn[i][k][n] + upper.mn[k][m][i] * lowered.mn[k][j][n]);
            result[i][j] += delta;
        }
    return result - 0.5 * yijLaplacian;
}
float3x3 SecondCovariantDerivativeLapse(float3x3 partialDels, float3 delA, float3 delW, float3x3 metric, float W, Christoffel upper)
{
    float3x3 delAdelW = TensorProduct(delA, delW);
    return Symmetrize(upper.CovariantDerivative(partialDels, delA, true) * W * W + (2. * delAdelW - metric * Trace(delAdelW, matInvSymUD(metric))) * W);
}
float3x3 SecondCovariantDerivativeW(float3x3 partialDels, float3 delW, Christoffel upper)
{
    return Symmetrize(upper.CovariantDerivative(partialDels, delW, true));
}

void YieldSingleDerivatives(StructuredBuffer<Voxel> voxels, int3 origin, out KAWGiNiBiDerivatives kaxginidel, out YijAijDerivatives yadel)
{
    Voxel del;
    float3 ddx = 1. / CoordinateMetric(origin);
    int3 offset = origin - clamp(origin - 3, 0, resolution - 7);
    
    del.Zero();
    for (int j = 0; j < 7; j++)
        del.TermwiseMAD(voxels[Idx(int3(j + origin.x - offset.x, origin.y, origin.z))], cdelO6[j + offset.x * 7] * ddx.x);
    
    kaxginidel.delNi[0] = del.N.xyz;
    kaxginidel.delKAW[0][0] = del.K;
    kaxginidel.delKAW[1][0] = del.N.w;
    kaxginidel.delKAW[2][0] = del.W;
    kaxginidel.delGi[0] = del.Gi;
    yadel.delAij[0] = del.Aij.toF3x3();
    yadel.delYij[0] = del.cYij.toF3x3();
    
    del.Zero();
    for (j = 0; j < 7; j++)
        del.TermwiseMAD(voxels[Idx(int3(origin.x, j + origin.y - offset.y, origin.z))], cdelO6[j + offset.y * 7] * ddx.y);
    
    kaxginidel.delNi[1] = del.N.xyz;
    kaxginidel.delKAW[0][1] = del.K;
    kaxginidel.delKAW[1][1] = del.N.w;
    kaxginidel.delKAW[2][1] = del.W;
    kaxginidel.delGi[1] = del.Gi;
    yadel.delAij[1] = del.Aij.toF3x3();
    yadel.delYij[1] = del.cYij.toF3x3();
    
    del.Zero();
    for (j = 0; j < 7; j++)
        del.TermwiseMAD(voxels[Idx(int3(origin.x, origin.y, j + origin.z - offset.z))], cdelO6[j + offset.z * 7] * ddx.z);
    
    kaxginidel.delNi[2] = del.N.xyz;
    kaxginidel.delKAW[0][2] = del.K;
    kaxginidel.delKAW[1][2] = del.N.w;
    kaxginidel.delKAW[2][2] = del.W;
    kaxginidel.delGi[2] = del.Gi;
    yadel.delAij[2] = del.Aij.toF3x3();
    yadel.delYij[2] = del.cYij.toF3x3();
}
