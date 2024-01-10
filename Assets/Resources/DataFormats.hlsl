#define expMask 0xF8000000u
#define expOff 18
#define expPos 27
#define f1Pos 18
#define f2Pos 9
#define s1 0x04000000u
#define f1 0x03FC0000u
#define s2 0x00020000u
#define f2 0x0001FE00u
#define s3 0x00000100u
#define f3 0x000000FFu
#define fracMul 255.0

struct f3Comp // [e5][s][f8][s][f8][s][f8]
{
    uint bits;
    float3 toF3()
    {
        int exponent = ((bits & expMask) >> expPos) - expOff;
        int sgn1 = (bits & s1) == 0 ? 1 : -1;
        int sgn2 = (bits & s2) == 0 ? 1 : -1;
        int sgn3 = (bits & s3) == 0 ? 1 : -1;
        int fr1 = (bits & f1) >> f1Pos;
        int fr2 = (bits & f2) >> f2Pos;
        int fr3 = bits & f3;
        return float3(fr1 * sgn1, fr2 * sgn2, fr3 * sgn3) * exp2(exponent) / fracMul;
    }
    void Set(float3 vec)
    {
        int3 sgn = sign(vec);
        vec *= sgn;
        
        float mx = max(vec.x, max(vec.y, vec.z));
        uint exponent = max(0, ceil(log2(mx)) + expOff);
        uint3 frc = clamp(uint3(vec * fracMul / exp2(float(exponent) - expOff)), 0, 0x000000FFu);
        bits = exponent << expPos | (sgn.x == -1 ? s1 : 0u) | (sgn.y == -1 ? s2 : 0u) | (sgn.z == -1 ? s3 : 0u) | (frc.x << f1Pos) | (frc.y << f2Pos) | frc.z;
    }
};

struct f3x3Comp
{
    f3Comp entries[3];
    
    float3x3 toF3x3()
    {
        return float3x3(entries[0].toF3(), entries[1].toF3(), entries[2].toF3());
    }
    void Set(float3x3 res)
    {
        entries[0].Set(res[0]);
        entries[1].Set(res[1]);
        entries[2].Set(res[2]);
    }
};

struct Sf3x3Comp
{
    // [00]  01   02
    // *01* [11]  12
    // *02* *12* [22]
    
    f3Comp entries[2];
    
    float3x3 toF3x3()
    {
        float3 v1 = entries[0].toF3();
        float3 v2 = entries[1].toF3();
        return float3x3(v1.x, v2.x, v2.y, v2.x, v1.y, v2.z, v2.y, v2.z, v1.z);
    }
    void Set(float3x3 res)
    {
        res = (res + transpose(res)) * 0.5;
        entries[0].Set(res._11_22_33);
        entries[1].Set(res._12_13_23);
    }
};

struct Sfloat3x3
{
    //  00   01  02
    // *01*  11  12
    // *02* *12* 22
    
    float3 _000;
    float3 _112;
    
    float3x3 toF3x3()
    {
        return float3x3(_000, float3(_000.y, _112.xy), float3(_000.z, _112.yz));
    }
    void Add(float3x3 mat)
    {
        mat = (mat + transpose(mat)) * 0.5;
        _000 += mat[0];
        _112 += float3(mat[1].yz, mat[2].z);
    }
    void TermwiseMAD(Sfloat3x3 mat, float v)
    {
        _000 += mat._000 * v;
        _112 += mat._112 * v;
    }
    void TermwiseMADS(float3x3 mat, float v)
    {
        mat = (mat + transpose(mat)) * 0.5;
        _000 += mat[0] * v;
        _112 += float3(mat[1].yz, mat[2].z) * v;
    }
    void Zero()
    {
        _000 = 0;
        _112 = 0;
    }
    void Mul(float v)
    {
        _000 *= v;
        _112 *= v;
    }
    void Set(float3x3 res)
    {
        res = (res + transpose(res)) * 0.5;
        _000 = res[0];
        _112 = float3(res[1].yz, res[2].z);
    }
};

struct f4Comp
{
    f3Comp v;
    float s;
    
    float4 toF4()
    {
        return float4(v.toF3(), s);
    }
    void Set(float4 val)
    {
        v.Set(val.xyz);
        s = val.w;
    }
};
