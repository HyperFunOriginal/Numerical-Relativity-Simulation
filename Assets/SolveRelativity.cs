using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System.IO;

public class SolveRelativity : MonoBehaviour
{
    StreamWriter logger;

    [Header("Simulation Properties")]
    public int resolution;
    public float lengthScale;
    public float timestep;
    public float vacuumEnergy;

    [Header("Initialization Properties")]
    public List<int> multigridResolutions;
    public List<int> relaxationIterations;

    [Header("Frame Saving Properties")]
    public bool saveFrames;
    float simTimer;

    string directory;
    bool initialized, cease;
    public RenderTexture temp;

    int voxels => resolution * resolution * resolution;
    float domainSize => -2f * CoordinateTransform(0);

    // Derivatives; 41 floats per voxel
    ComputeBuffer sVs; // 9
    ComputeBuffer Ts; // 12
    ComputeBuffer raised; // 6
    ComputeBuffer lowered; // 6
    ComputeBuffer derived; // 9

    // Auxiliary Fields; 4 floats per voxel
    ComputeBuffer MassCurrent; // 2
    ComputeBuffer SpatialStress; // 2

    // Fields; 63 floats per voxel
    ComputeBuffer old; // 21
    ComputeBuffer current; // 21
    ComputeBuffer next; // 21

    // Temporary Buffer
    ComputeBuffer u;

    [Header("Compute Shaders")]
    public ComputeShader precompute;
    public int Derivatives => precompute.FindKernel("Derivatives");
    public int ComputeChristoffels => precompute.FindKernel("ComputeChristoffels");
    public int ComputeConformalRicci => precompute.FindKernel("ComputeConformalRicci");
    public int ComputeDerived => precompute.FindKernel("ComputeDerived");
    public int ComputeDerived2 => precompute.FindKernel("ComputeDerived2");

    public ComputeShader evolve;
    public int WK => evolve.FindKernel("WK");
    public int YAij => evolve.FindKernel("YAij");
    public int cGi => evolve.FindKernel("cGi");
    public int ConstraintDamp => evolve.FindKernel("ConstraintDamp");
    public int Transfer => evolve.FindKernel("Transfer");

    public ComputeShader postProcess;
    public int RenderToScreenSlice => postProcess.FindKernel("RenderToScreenSlice");
    public int SommerfeldRadiation => postProcess.FindKernel("SommerfeldRadiation");
    public int EvolveSlicing => postProcess.FindKernel("EvolveSlicing");
    public int KreissOligerX => postProcess.FindKernel("KreissOligerX");
    public int KreissOligerY => postProcess.FindKernel("KreissOligerY");
    public int KreissOligerZ => postProcess.FindKernel("KreissOligerZ");

    public ComputeShader init;
    public int UpscaleU => init.FindKernel("UpscaleU");
    public int Initialize => init.FindKernel("Initialize");
    public int InitKijAlphaU => init.FindKernel("InitKijAlphaU");
    public int DownScaleKijAlphaU => init.FindKernel("DownScaleKijAlphaU");
    public int ConstraintSolveBowenYork => init.FindKernel("ConstraintSolveBowenYork");

    // Start is called before the first frame update
    void Start()
    {
        cease = false;
        initialized = false;
        restTime = 0f;
        simTimer = 0f;

        StartCoroutine(StartAndUpdate());
    }

    IEnumerator InitializePoisson()
    {
        multigridResolutions.Add(resolution);
        List<int> offsets = new List<int>() { 0 };

        for (int i = 0; i < multigridResolutions.Count; i++)
            offsets.Add(offsets[offsets.Count - 1] + multigridResolutions[i] * multigridResolutions[i] * multigridResolutions[i]);

        u = new ComputeBuffer(offsets[offsets.Count - 1], sizeof(float));
        ComputeBuffer ak = new ComputeBuffer(offsets[offsets.Count - 1], sizeof(float) * 2);

        init.SetInt("offset", offsets[offsets.Count - 2]);
        init.SetBuffer(InitKijAlphaU, "uBuffer", u);
        init.SetBuffer(InitKijAlphaU, "kAlphaBuffer", ak);
        yield return Dispatch(InitKijAlphaU, init, 16, 8, 8);

        for (int i = multigridResolutions.Count - 1; i > 0; i--)
        {
            int oldRes = multigridResolutions[i];
            int newRes = multigridResolutions[i - 1];

            init.SetInt("subresolution", oldRes);
            init.SetInt("subresolution2", newRes);
            init.SetInt("offset", offsets[i]);
            init.SetInt("offset2", offsets[i - 1]);

            init.SetBuffer(DownScaleKijAlphaU, "uBuffer", u);
            init.SetBuffer(DownScaleKijAlphaU, "kAlphaBuffer", ak);
            init.Dispatch(DownScaleKijAlphaU, Mathf.CeilToInt(newRes / 16f), Mathf.CeilToInt(newRes / 8f), Mathf.CeilToInt(newRes / 8f));
        }
        for (int i = 0; i < multigridResolutions.Count; i++)
        {
            int currentRes = multigridResolutions[i];

            init.SetInt("offset", offsets[i]);
            init.SetInt("subresolution", currentRes);

            for (int j = 0; j <= relaxationIterations[Mathf.Clamp(i, 0, relaxationIterations.Count - 1)]; j++)
            {
                init.SetBuffer(ConstraintSolveBowenYork, "uBuffer", u);
                init.SetBuffer(ConstraintSolveBowenYork, "kAlphaBuffer", ak);
                init.Dispatch(ConstraintSolveBowenYork, Mathf.CeilToInt(currentRes / 16f), Mathf.CeilToInt(currentRes / 8f), Mathf.CeilToInt(currentRes / 8f));
                if (j % (10000 / currentRes) == 0)
                    yield return null;
            }

            if (i != multigridResolutions.Count - 1)
            {
                init.SetInt("subresolution", multigridResolutions[i + 1]);
                init.SetInt("subresolution2", currentRes);
                init.SetInt("offset", offsets[i + 1]);
                init.SetInt("offset2", offsets[i]);

                init.SetBuffer(UpscaleU, "uBuffer", u);
                init.Dispatch(UpscaleU, Mathf.CeilToInt(multigridResolutions[i + 1] / 16f), Mathf.CeilToInt(multigridResolutions[i + 1] / 8f), Mathf.CeilToInt(multigridResolutions[i + 1] / 8f));
            }
        }
        ak.Dispose();
    }

    IEnumerator InitialiseVariables()
    {
        directory = Application.dataPath;
        directory = directory.Remove(directory.LastIndexOfAny(new char[] { '\\', '/' })) + "\\Frames\\";

        logger = new StreamWriter(directory + "Log.log", true);
        logger.AutoFlush = true;

        SetConstants(new Vector3(0, 1, 1));
        yield return new WaitForEndOfFrame();
        temp = new RenderTexture(resolution * 10, resolution * 10, 0) { enableRandomWrite = true };
        temp.Create();

        MassCurrent = new ComputeBuffer(voxels, sizeof(float) * 2);
        SpatialStress = new ComputeBuffer(voxels, sizeof(float) * 2);
        old = new ComputeBuffer(voxels, sizeof(float) * 21);
        current = new ComputeBuffer(voxels, sizeof(float) * 21);
        next = new ComputeBuffer(voxels, sizeof(float) * 21);

        sVs = new ComputeBuffer(voxels, sizeof(float) * 9);
        Ts = new ComputeBuffer(voxels, sizeof(float) * 12);
        raised = new ComputeBuffer(voxels, sizeof(float) * 6);
        lowered = new ComputeBuffer(voxels, sizeof(float) * 6);
        derived = new ComputeBuffer(voxels, sizeof(float) * 9);
        initialized = true;

        yield return InitializePoisson();

        init.SetBuffer(Initialize, "uBuffer", u);
        init.SetBuffer(Initialize, "MassCurrent", MassCurrent);
        init.SetBuffer(Initialize, "SpatialStress", SpatialStress);
        init.SetBuffer(Initialize, "old", old);
        init.SetBuffer(Initialize, "next", next);
        init.SetBuffer(Initialize, "current", current);
        yield return Dispatch(Initialize, init, 16, 8, 8);

        u.Dispose();

        string log = "New simulation successfully started! \n\nSimulation Properties: \n  Resolution: " + resolution.ToString() + "\n  Timestep: " + timestep.ToString("f4") + "\n  Base Length Scale: " + lengthScale.ToString("f4") + "\n  Vacuum Energy: " + vacuumEnergy.ToString("f5") + "\n  Domain Size: " + domainSize.ToString("f4") + "\n  Saving frames to disk: " + saveFrames.ToString() + "\n\nMultigrid Initialization:\n";
        for (int i = 0; i < multigridResolutions.Count; i++)
            log += multigridResolutions[i].ToString() + (i != multigridResolutions.Count - 1 ? ", " : "\n\nRelaxation Iterations: \n");
        for (int i = 0; i < relaxationIterations.Count; i++)
            log += relaxationIterations[i].ToString() + (i != relaxationIterations.Count - 1 ? ", " : "\n\nTotal Complexity Score: ");

        float score = voxels / timestep;
        for (int i = 0; i < multigridResolutions.Count; i++)
            score += multigridResolutions[i] * multigridResolutions[i] * multigridResolutions[i] * relaxationIterations[Mathf.Clamp(i, 0, relaxationIterations.Count - 1)] * .001f;

        WriteToExternalLog(log + (score * 1E-3f).ToString("f3"));
    }
    void SetConstants(Vector3 ambient)
    {
        precompute.SetInt("globalSeed", Random.Range(int.MinValue + 1, int.MaxValue));
        precompute.SetInt("resolution", resolution);
        precompute.SetFloat("lengthScale", lengthScale);
        precompute.SetFloat("timestep", timestep);
        precompute.SetFloat("vacuumEnergy", vacuumEnergy);

        evolve.SetInt("resolution", resolution);
        evolve.SetFloat("lengthScale", lengthScale);
        evolve.SetFloat("timestep", timestep);
        evolve.SetFloat("vacuumEnergy", vacuumEnergy);

        postProcess.SetInt("resolution", resolution);
        postProcess.SetFloats("ambientKAW", ambient.x, ambient.y, ambient.z);
        postProcess.SetFloat("lengthScale", lengthScale);
        postProcess.SetFloat("timestep", timestep);
        postProcess.SetFloat("vacuumEnergy", vacuumEnergy);

        init.SetInt("resolution", resolution);
        init.SetFloat("lengthScale", lengthScale);
        init.SetFloat("timestep", timestep);
        init.SetFloat("vacuumEnergy", vacuumEnergy);
    }

    IEnumerator StartAndUpdate()
    {
        Vector3 ambientSpacetime = new Vector3(0, 1, 1); // K; A; W
        int frameCount = 0, imageIndex = 0; 
        float timer = 0f;

        yield return InitialiseVariables();
        while (!cease)
        {
            float frameTime = Time.realtimeSinceStartup;
            Vector3 curr = ambientSpacetime;

            for (int i = 0; i < 2; i++)
            {
                SetConstants(curr);
                yield return Precompute();
                yield return EvolveInner();
                if (i == 1)
                {
                    if (frameCount % 3 == 0)
                    {
                        postProcess.SetBuffer(KreissOligerX, "next", next);
                        postProcess.SetBuffer(KreissOligerX, "current", current);
                        yield return Dispatch(KreissOligerX, postProcess, 12, 10, 8);
                    }
                    else if (frameCount % 3 == 1)
                    {
                        postProcess.SetBuffer(KreissOligerY, "next", next);
                        postProcess.SetBuffer(KreissOligerY, "current", current);
                        yield return Dispatch(KreissOligerY, postProcess, 12, 10, 8);
                    }
                    else
                    {
                        postProcess.SetBuffer(KreissOligerZ, "next", next);
                        postProcess.SetBuffer(KreissOligerZ, "current", current);
                        yield return Dispatch(KreissOligerZ, postProcess, 12, 10, 8);
                    }
                }
                yield return TransferData(next, current);
                curr = Mathf.Abs(vacuumEnergy) < 1E-7f ? ambientSpacetime : EvolveAmbient(ambientSpacetime, curr);
            }
            yield return TransferData(current, old);
            ambientSpacetime = curr;

            if (frameCount % 5 == 4)
            {
                string log = "[Simulation State] " + ((Time.realtimeSinceStartup - frameTime) * 1000f).ToString("f1") + "ms per frame, Simulation Time: " + simTimer.ToString("f2") + " M\n[Ambient State] K_inf: ";
                WriteToExternalLog(log + ambientSpacetime.x.ToString("f4") + ", A_inf: " + ambientSpacetime.y.ToString("f4") + ", W_inf: " + ambientSpacetime.z.ToString("f4"));
            }
            ScreenAndIO(ref timer, ref imageIndex);

            simTimer += timestep / 10f;
            timer += timestep / 10f;
            frameCount++;
        }
    }

    void ScreenAndIO(ref float timer, ref int imageIndex)
    {
        postProcess.SetTexture(RenderToScreenSlice, "Result", temp);
        postProcess.SetBuffer(RenderToScreenSlice, "derived", derived);
        postProcess.SetBuffer(RenderToScreenSlice, "sVs", sVs);
        postProcess.SetBuffer(RenderToScreenSlice, "next", next);
        postProcess.Dispatch(RenderToScreenSlice, Mathf.CeilToInt(temp.width / 32f), Mathf.CeilToInt(temp.height / 32f), 1);

        if (timer > .2f)
        {
            if (saveFrames)
            {
                SaveImage.SaveImageToFile(temp, directory, imageIndex.ToString());
                imageIndex++;
            }
            timer -= .2f;
        }
    }
    Vector3 EvolveAmbient(Vector3 ambientSpacetime, Vector3 current)
    {
        Vector3 backwardsEulerIter = ambientSpacetime + new Vector3(current.y * (current.x * current.x / 3f - vacuumEnergy), -2f * current.y * current.x, current.z * current.x * current.y / 3f) * timestep;
        return new Vector3(backwardsEulerIter.x, Mathf.Clamp01(backwardsEulerIter.y), Mathf.Clamp(backwardsEulerIter.z, 1E-4f, 1E+4f));
    }
    IEnumerator Precompute()
    {
        precompute.SetBuffer(Derivatives, "current", current);
        precompute.SetBuffer(Derivatives, "sVs", sVs);
        precompute.SetBuffer(Derivatives, "Ts", Ts);
        yield return Dispatch(Derivatives, precompute, 8, 8, 8);

        precompute.SetBuffer(ComputeChristoffels, "current", current);
        precompute.SetBuffer(ComputeChristoffels, "lowered", lowered);
        precompute.SetBuffer(ComputeChristoffels, "raised", raised);
        precompute.SetBuffer(ComputeChristoffels, "Ts", Ts);
        yield return Dispatch(ComputeChristoffels, precompute, 14, 13, 5);

        precompute.SetBuffer(ComputeConformalRicci, "current", current);
        precompute.SetBuffer(ComputeConformalRicci, "derived", derived);
        precompute.SetBuffer(ComputeConformalRicci, "lowered", lowered);
        precompute.SetBuffer(ComputeConformalRicci, "raised", raised);
        precompute.SetBuffer(ComputeConformalRicci, "sVs", sVs);
        precompute.SetBuffer(ComputeConformalRicci, "Ts", Ts);
        yield return Dispatch(ComputeConformalRicci, precompute, 11, 9, 5);

        precompute.SetBuffer(ComputeDerived, "current", current);
        precompute.SetBuffer(ComputeDerived, "derived", derived);
        precompute.SetBuffer(ComputeDerived, "MassCurrent", MassCurrent);
        precompute.SetBuffer(ComputeDerived, "raised", raised);
        precompute.SetBuffer(ComputeDerived, "sVs", sVs);
        yield return Dispatch(ComputeDerived, precompute, 8, 8, 8);

        precompute.SetBuffer(ComputeDerived2, "current", current);
        precompute.SetBuffer(ComputeDerived2, "derived", derived);
        precompute.SetBuffer(ComputeDerived2, "MassCurrent", MassCurrent);
        precompute.SetBuffer(ComputeDerived2, "raised", raised);
        precompute.SetBuffer(ComputeDerived2, "sVs", sVs);
        precompute.SetBuffer(ComputeDerived2, "Ts", Ts);
        yield return Dispatch(ComputeDerived2, precompute, 11, 11, 5);
    }
    IEnumerator EvolveInner()
    {
        evolve.SetBuffer(WK, "MassCurrent", MassCurrent);
        evolve.SetBuffer(WK, "SpatialStress", SpatialStress);
        evolve.SetBuffer(WK, "derived", derived);
        evolve.SetBuffer(WK, "sVs", sVs);
        evolve.SetBuffer(WK, "old", old);
        evolve.SetBuffer(WK, "next", next);
        evolve.SetBuffer(WK, "current", current);
        yield return Dispatch(WK, evolve, 16, 8, 8);

        evolve.SetBuffer(YAij, "SpatialStress", SpatialStress);
        evolve.SetBuffer(YAij, "derived", derived);
        evolve.SetBuffer(YAij, "Ts", Ts);
        evolve.SetBuffer(YAij, "sVs", sVs);
        evolve.SetBuffer(YAij, "old", old);
        evolve.SetBuffer(YAij, "next", next);
        evolve.SetBuffer(YAij, "current", current);
        yield return Dispatch(YAij, evolve, 8, 8, 9);

        evolve.SetBuffer(cGi, "MassCurrent", MassCurrent);
        evolve.SetBuffer(cGi, "raised", raised);
        evolve.SetBuffer(cGi, "sVs", sVs);
        evolve.SetBuffer(cGi, "old", old);
        evolve.SetBuffer(cGi, "next", next);
        evolve.SetBuffer(cGi, "current", current);
        yield return Dispatch(cGi, evolve, 13, 10, 5);

        postProcess.SetBuffer(EvolveSlicing, "sVs", sVs);
        postProcess.SetBuffer(EvolveSlicing, "old", old);
        postProcess.SetBuffer(EvolveSlicing, "next", next);
        postProcess.SetBuffer(EvolveSlicing, "current", current);
        yield return Dispatch(EvolveSlicing, postProcess, 16, 8, 8);

        evolve.SetBuffer(ConstraintDamp, "raised", raised);
        evolve.SetBuffer(ConstraintDamp, "derived", derived);
        evolve.SetBuffer(ConstraintDamp, "sVs", sVs);
        evolve.SetBuffer(ConstraintDamp, "next", next);
        evolve.SetBuffer(ConstraintDamp, "current", current);
        yield return Dispatch(ConstraintDamp, evolve, 10, 8, 7);

        postProcess.SetBuffer(SommerfeldRadiation, "Ts", Ts);
        postProcess.SetBuffer(SommerfeldRadiation, "sVs", sVs);
        postProcess.SetBuffer(SommerfeldRadiation, "next", next);
        postProcess.SetBuffer(SommerfeldRadiation, "current", current);
        yield return Dispatch(SommerfeldRadiation, postProcess, 8, 8, 9);
    }
    IEnumerator TransferData(ComputeBuffer from, ComputeBuffer to)
    {
        evolve.SetBuffer(Transfer, "transfer1", from);
        evolve.SetBuffer(Transfer, "transfer2", to);
        yield return Dispatch(Transfer, evolve, 16, 8, 8);
    }

    float restTime;
    IEnumerator Dispatch(int kernel, ComputeShader shader, int a, int b, int c)
    {
        shader.Dispatch(kernel, Mathf.CeilToInt(resolution / (float)a), Mathf.CeilToInt(resolution / (float)b), Mathf.CeilToInt(resolution / (float)c));
        restTime += voxels * 2E-6f / (a * b * c);
        if (restTime > .04f)
        {
            yield return new WaitForSecondsRealtime(restTime);
            restTime = 0f;
        }
    }

    public void WriteToExternalLog(string text)
    {
        logger.WriteLine("[" + System.DateTime.Now.ToString() + "] : \n" + text + "\n");
        Debug.Log(text);
    }
    public float CoordinateTransform(float id)
    { 
        id = (id + .5f) * 2f / resolution - 1f;
        return Mathf.Log((1f + id) / (1f - id)) * .25f * resolution * lengthScale;
    }
    public float InverseCoordinateTransform(float position)
    { 
        position = Mathf.Exp(position / (.25f * resolution * lengthScale));
        return Mathf.Round(((position - 1f)/(position + 1f) + 1f) * .5f * resolution - .5f);
    }
    public float CoordinateMetric(float id)
    {
        id = (id + .5f) * 2f / resolution - 1f;
        return lengthScale / (1f - id * id);
    }

    private void OnDestroy()
    {
        if (!initialized)
            return;

        sVs             .Dispose();
        Ts              .Dispose();
        raised          .Dispose();
        lowered         .Dispose();
        derived         .Dispose();
        MassCurrent     .Dispose();
        SpatialStress   .Dispose();
        old             .Dispose();
        current         .Dispose();
        next            .Dispose();
        logger.Close();

        temp.Release();
        DestroyImmediate(temp, true);
    }
    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        Graphics.Blit(temp, destination);
    }
}
