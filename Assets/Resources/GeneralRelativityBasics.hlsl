#include "TensorCalculus.hlsl"
#include "DataFormats.hlsl"

float timestep;
float lengthScale;
float vacuumEnergy;
int resolution;

float3 CoordinateTransform(float3 id)
{
    id = (id + .5) * 2. / resolution - 1.;
    return log((1. + id) / (1. - id)) * .25 * resolution * lengthScale;
}
float3 InverseCoordinateTransform(float3 position)
{
    position /= .5 * resolution * lengthScale;
    return round((tanh(position) + 1.) * .5 * resolution - .5);
}
float3 CoordinateMetric(float3 id)
{
    id = (id + .5) * 2. / resolution - 1.;
    return lengthScale / (1. - id * id);
}

float LerpFactor(int3 id)
{
    int3 minDistsToBorder = min(id + 10., resolution + 9. - id);
    return clamp(min(min(minDistsToBorder.x, minDistsToBorder.y), minDistsToBorder.z) * float(2. / (resolution + 20.)), 0., 1.);
}
float3 RadialVector(int3 id)
{
    float3 pos = CoordinateTransform(id);
    return pos * rsqrt(dot(pos, pos) + lengthScale * lengthScale * .01);
}
bool EdgeOfDomain(int3 id, int edgeDist)
{
    return dot(abs(clamp(id, edgeDist, resolution - edgeDist - 1) - id), 1) != 0;
}
float4x4 Projector(float3 Ni, float A)
{
    return I4 + TensorProduct(float4(-Ni, 1.) / A, float4(0, 0, 0, -A));
}

struct Christoffel
{
    float3x3 mn[3];
    
    void Yield(out Christoffel lower, float3x3 invMetric, float3x3 metricDeriv[3])
    {
        for (int c = 0; c < 3; c++)
        {
            lower.mn[c] = -metricDeriv[c];
            for (int a = 0; a < 3; a++)
            {
                lower.mn[c][a] += metricDeriv[a][c];
                for (int b = 0; b < 3; b++)
                    lower.mn[c][a][b] += metricDeriv[b][c][a];
            }
            lower.mn[c] = Symmetrize(lower.mn[c] * 0.5);
        }
        mn[0] = invMetric[0][0] * lower.mn[0] + invMetric[0][1] * lower.mn[1] + invMetric[0][2] * lower.mn[2];
        mn[1] = invMetric[1][0] * lower.mn[0] + invMetric[1][1] * lower.mn[1] + invMetric[1][2] * lower.mn[2];
        mn[2] = invMetric[2][0] * lower.mn[0] + invMetric[2][1] * lower.mn[1] + invMetric[2][2] * lower.mn[2];
    }
    float3 CovariantDerivative(int dir, float3 pdVec, float3 vec, bool covariant)
    {
        int i = 0;
        if (!covariant)
            for (; i < 3; i++)
                pdVec[i] += dot(mn[i][dir], vec);
        else
            for (; i < 3; i++)
                pdVec -= mn[i][dir] * vec[i];
        return pdVec;
    }
    float3x3 CovariantDerivative(float3x3 pdVec, float3 vec, bool covariant)
    {
        for (int i = 0; i < 3; i++)
            pdVec[i] = CovariantDerivative(i, pdVec[i], vec, covariant);
        return pdVec;
    }
    float3x3 CovariantDerivative(int dir, float3x3 pdT, float3x3 tensor)
    {
        for (int i = 0; i < 3; i++)
            for (int j = 0; j < 3; j++)
                for (int k = 0; k < 3; k++)
                    pdT[i][j] -= mn[k][dir][i] * tensor[k][j] + mn[k][dir][j] * tensor[i][k];
        return pdT;
    }
    void CovariantDerivative(inout float3x3 pdT[3], float3x3 tensor)
    {
        for (int i = 0; i < 3; i++)
            pdT[i] = CovariantDerivative(i, pdT[i], tensor);
    }
};
struct CompressedChristoffel
{
    // Stride 6 floats
    Sf3x3Comp mn[3];
    
    void Compress(Christoffel original)
    {
        mn[0].Set(original.mn[0]);
        mn[1].Set(original.mn[1]);
        mn[2].Set(original.mn[2]);
    }
    Christoffel Decompress()
    {
        Christoffel result;
        result.mn[0] = mn[0].toF3x3();
        result.mn[1] = mn[1].toF3x3();
        result.mn[2] = mn[2].toF3x3();
        return result;
    }
};