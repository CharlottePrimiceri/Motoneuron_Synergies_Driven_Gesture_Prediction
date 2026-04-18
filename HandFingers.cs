using UnityEngine;
using System.Collections.Generic;
using System.Globalization;

public class MoveFingers : MonoBehaviour
{
    public TextAsset csvFile;
    public float sampleRate = 200f;

    public enum Axis { X, Y, Z }

    [Header("Abduction Axis")]
    public Axis abductionAxis = Axis.Y;

    [Header("Thumb")]
    public Transform thumb1;
    public Transform thumb2;
    public float thumbMcpScale = 1f;
    public float thumbIpScale = 1f;
    public bool invertThumbMcp = true;
    public bool invertThumbIp = true;

    [Header("Index")]
    public Transform index1;
    public Transform index2;
    public Transform index3;
    public float indexMcpScale = 1f;
    public float indexPipScale = 1f;
    public float indexDipFactor = 0.6f;
    public bool invertIndexMcp = true;
    public bool invertIndexPip = true;
    public bool invertIndexDip = true;

    [Header("Middle")]
    public Transform middle1;
    public Transform middle2;
    public Transform middle3;
    public float middleMcpScale = 1f;
    public float middlePipScale = 1f;
    public float middleDipFactor = 0.6f;
    public bool invertMiddleMcp = true;
    public bool invertMiddlePip = true;
    public bool invertMiddleDip = true;

    [Header("Ring")]
    public Transform ring1;
    public Transform ring2;
    public Transform ring3;
    public float ringMcpScale = 1f;
    public float ringPipScale = 1f;
    public float ringDipFactor = 0.6f;
    public bool invertRingMcp = true;
    public bool invertRingPip = true;
    public bool invertRingDip = true;

    [Header("Little")]
    public Transform little1;
    public Transform little2;
    public Transform little3;
    public float littleMcpScale = 1f;
    public float littlePipScale = 1f;
    public float littleDipFactor = 0.6f;
    public bool invertLittleMcp = true;
    public bool invertLittlePip = true;
    public bool invertLittleDip = true;

    [Header("Abduction Scales")]
    public float thumbIndexAbdScale = 1f;
    public float indexMiddleAbdScale = 1f;
    public float middleRingAbdScale = 1f;
    public float ringLittleAbdScale = 1f;

    [Header("Abduction Inversion")]
    public bool invertThumbIndexAbd = false;
    public bool invertIndexMiddleAbd = false;
    public bool invertMiddleRingAbd = false;
    public bool invertRingLittleAbd = false;

    private List<float[]> samples = new List<float[]>();
    private int currentFrame = 0;
    private float timer = 0f;

    private Quaternion thumb1Start, thumb2Start;
    private Quaternion index1Start, index2Start, index3Start;
    private Quaternion middle1Start, middle2Start, middle3Start;
    private Quaternion ring1Start, ring2Start, ring3Start;
    private Quaternion little1Start, little2Start, little3Start;

    void Start()
    {
        SaveInitialRotations();
        LoadCSV();
        Debug.Log("Loaded samples: " + samples.Count);
    }

    void Update()
    {
        if (samples.Count == 0) return;

        timer += Time.deltaTime;
        float dt = 1f / sampleRate;

        while (timer >= dt)
        {
            timer -= dt;

            if (currentFrame >= samples.Count)
                currentFrame = 0;

            float[] s = samples[currentFrame];

            // CSV glove_unity_deg.csv
            // 0  time_s
            // 1  Thumb_MCP
            // 2  Thumb_IP
            // 3  Thumb_Index_abd
            // 4  Index_MCP
            // 5  Index_PIP
            // 6  Index_Middle_abd
            // 7  Middle_MCP
            // 8  Middle_PIP
            // 9  Middle_Ring_abd
            // 10 Ring_MCP
            // 11 Ring_PIP
            // 12 Ring_Little_abd
            // 13 Little_MCP
            // 14 Little_PIP

            float thumbIndexAbd = s[3] * thumbIndexAbdScale;
            float indexMiddleAbd = s[6] * indexMiddleAbdScale;
            float middleRingAbd = s[9] * middleRingAbdScale;
            float ringLittleAbd = s[12] * ringLittleAbdScale;

            if (invertThumbIndexAbd) thumbIndexAbd = -thumbIndexAbd;
            if (invertIndexMiddleAbd) indexMiddleAbd = -indexMiddleAbd;
            if (invertMiddleRingAbd) middleRingAbd = -middleRingAbd;
            if (invertRingLittleAbd) ringLittleAbd = -ringLittleAbd;

            // FLEXION + ABDUCTION SUI BONES BASE
            ApplyFingerWithAbduction(
                thumb1, thumb1Start,
                s[1] * thumbMcpScale, invertThumbMcp,
                0.5f * thumbIndexAbd
            );
            ApplyFinger(thumb2, thumb2Start, s[2] * thumbIpScale, invertThumbIp);

            ApplyFingerWithAbduction(
                index1, index1Start,
                s[4] * indexMcpScale, invertIndexMcp,
                (-0.5f * thumbIndexAbd) + (0.5f * indexMiddleAbd)
            );
            ApplyFinger(index2, index2Start, s[5] * indexPipScale, invertIndexPip);
            ApplyFinger(index3, index3Start, s[5] * indexPipScale * indexDipFactor, invertIndexDip);

            ApplyFingerWithAbduction(
                middle1, middle1Start,
                s[7] * middleMcpScale, invertMiddleMcp,
                (-0.5f * indexMiddleAbd) + (0.5f * middleRingAbd)
            );
            ApplyFinger(middle2, middle2Start, s[8] * middlePipScale, invertMiddlePip);
            ApplyFinger(middle3, middle3Start, s[8] * middlePipScale * middleDipFactor, invertMiddleDip);

            ApplyFingerWithAbduction(
                ring1, ring1Start,
                s[10] * ringMcpScale, invertRingMcp,
                (-0.5f * middleRingAbd) + (0.5f * ringLittleAbd)
            );
            ApplyFinger(ring2, ring2Start, s[11] * ringPipScale, invertRingPip);
            ApplyFinger(ring3, ring3Start, s[11] * ringPipScale * ringDipFactor, invertRingDip);

            ApplyFingerWithAbduction(
                little1, little1Start,
                s[13] * littleMcpScale, invertLittleMcp,
                (-0.5f * ringLittleAbd)
            );
            ApplyFinger(little2, little2Start, s[14] * littlePipScale, invertLittlePip);
            ApplyFinger(little3, little3Start, s[14] * littlePipScale * littleDipFactor, invertLittleDip);

            currentFrame++;
        }
    }

    void ApplyFinger(Transform bone, Quaternion startRot, float flexDeg, bool invertFlex)
    {
        if (bone == null) return;

        if (invertFlex) flexDeg = -flexDeg;

        bone.localRotation = startRot * Quaternion.Euler(0f, 0f, flexDeg);
    }

    void ApplyFingerWithAbduction(Transform bone, Quaternion startRot, float flexDeg, bool invertFlex, float abdDeg)
    {
        if (bone == null) return;

        if (invertFlex) flexDeg = -flexDeg;

        Vector3 euler;

        switch (abductionAxis)
        {
            case Axis.X:
                euler = new Vector3(abdDeg, 0f, flexDeg);
                break;
            case Axis.Y:
                euler = new Vector3(0f, abdDeg, flexDeg);
                break;
            default:
                euler = new Vector3(0f, 0f, flexDeg + abdDeg);
                break;
        }

        bone.localRotation = startRot * Quaternion.Euler(euler);
    }

    void SaveInitialRotations()
    {
        if (thumb1 != null) thumb1Start = thumb1.localRotation;
        if (thumb2 != null) thumb2Start = thumb2.localRotation;

        if (index1 != null) index1Start = index1.localRotation;
        if (index2 != null) index2Start = index2.localRotation;
        if (index3 != null) index3Start = index3.localRotation;

        if (middle1 != null) middle1Start = middle1.localRotation;
        if (middle2 != null) middle2Start = middle2.localRotation;
        if (middle3 != null) middle3Start = middle3.localRotation;

        if (ring1 != null) ring1Start = ring1.localRotation;
        if (ring2 != null) ring2Start = ring2.localRotation;
        if (ring3 != null) ring3Start = ring3.localRotation;

        if (little1 != null) little1Start = little1.localRotation;
        if (little2 != null) little2Start = little2.localRotation;
        if (little3 != null) little3Start = little3.localRotation;
    }

    void LoadCSV()
    {
        samples.Clear();

        if (csvFile == null)
        {
            Debug.LogError("CSV file not assigned.");
            return;
        }

        string[] lines = csvFile.text.Split('\n');

        for (int i = 1; i < lines.Length; i++)
        {
            string line = lines[i].Trim();
            if (string.IsNullOrWhiteSpace(line)) continue;

            string[] parts = line.Split(',');
            float[] row = new float[parts.Length];

            bool validRow = true;
            for (int j = 0; j < parts.Length; j++)
            {
                if (!float.TryParse(parts[j], NumberStyles.Float, CultureInfo.InvariantCulture, out row[j]))
                {
                    validRow = false;
                    break;
                }
            }

            if (validRow) samples.Add(row);
        }
    }
}