using System;
using System.Collections;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Text;
using UnityEngine;
using Debug = UnityEngine.Debug;

// Starts only when the player is launched by Scripts/export-video.sh.
internal sealed class WallwallVideoExport : MonoBehaviour
{
    private Process encoder;
    private string partialPath;
    private bool completed;
    private readonly StringBuilder encoderErrors = new StringBuilder();

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    private static void StartExport()
    {
        string[] args = Environment.GetCommandLineArgs();
        if (Array.IndexOf(args, "--wallwall-export-video") < 0) return;
        var host = new GameObject("WallwallVideoExport");
        DontDestroyOnLoad(host);
        host.AddComponent<WallwallVideoExport>();
    }

    private void Start()
    {
        try
        {
            string[] args = Environment.GetCommandLineArgs();
            string output = RequiredArgument(args, "--wallwall-export-video");
            string ffmpeg = RequiredArgument(args, "--wallwall-ffmpeg");
            int seconds = PositiveArgument(args, "--wallwall-seconds", 30, 3600);
            int fps = PositiveArgument(args, "--wallwall-fps", 30, 60);
            if (!Path.IsPathRooted(output) || !Path.IsPathRooted(ffmpeg))
                throw new ArgumentException("Output and FFmpeg paths must be absolute");
            if (!File.Exists(ffmpeg)) throw new FileNotFoundException("FFmpeg was not found", ffmpeg);
            if (!Directory.Exists(Path.GetDirectoryName(output)))
                throw new DirectoryNotFoundException("Output directory does not exist: " + output);
            if (File.Exists(output)) throw new IOException("Output already exists: " + output);

            partialPath = output + "." + Guid.NewGuid().ToString("N") + ".partial.mp4";
            Time.captureFramerate = fps;
            Application.runInBackground = true;
            QualitySettings.vSyncCount = 0;
            StartEncoder(ffmpeg, fps);
            StartCoroutine(Capture(output, seconds * fps));
        }
        catch (Exception error)
        {
            Fail(error);
        }
    }

    private static string RequiredArgument(string[] args, string name)
    {
        int index = Array.IndexOf(args, name);
        if (index < 0 || index + 1 >= args.Length || args[index + 1].StartsWith("--"))
            throw new ArgumentException("Missing " + name + " value");
        return args[index + 1];
    }

    private static int PositiveArgument(string[] args, string name, int fallback, int maximum)
    {
        int index = Array.IndexOf(args, name);
        if (index < 0) return fallback;
        if (index + 1 >= args.Length ||
            !int.TryParse(args[index + 1], NumberStyles.None, CultureInfo.InvariantCulture, out int value) ||
            value < 1 || value > maximum)
            throw new ArgumentException(name + " must be between 1 and " + maximum);
        return value;
    }

    private static string Quote(string value)
    {
        return "\"" + value.Replace("\\", "\\\\").Replace("\"", "\\\"") + "\"";
    }

    private void StartEncoder(string ffmpeg, int fps)
    {
        var info = new ProcessStartInfo
        {
            FileName = ffmpeg,
            Arguments = "-hide_banner -loglevel error -nostdin -f image2pipe -framerate " +
                fps.ToString(CultureInfo.InvariantCulture) +
                " -vcodec png -i pipe:0 -vf " + Quote("pad=ceil(iw/2)*2:ceil(ih/2)*2") +
                " -an -c:v libx264 -pix_fmt yuv420p -movflags +faststart -n " +
                Quote(partialPath),
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardInput = true,
            RedirectStandardError = true,
        };
        encoder = new Process { StartInfo = info };
        encoder.ErrorDataReceived += (sender, eventArgs) =>
        {
            if (eventArgs.Data == null) return;
            lock (encoderErrors)
            {
                if (encoderErrors.Length < 8192)
                    encoderErrors.AppendLine(eventArgs.Data);
            }
        };
        if (!encoder.Start()) throw new IOException("Could not start FFmpeg");
        encoder.BeginErrorReadLine();
    }

    private IEnumerator Capture(string output, int frameCount)
    {
        Texture2D frame = null;
        for (int index = 0; index < frameCount; index++)
        {
            yield return new WaitForEndOfFrame();
            Exception captureError = null;
            try
            {
                if (frame == null)
                    frame = new Texture2D(Screen.width, Screen.height, TextureFormat.RGB24, false);
                if (frame.width != Screen.width || frame.height != Screen.height)
                    throw new IOException("Screen dimensions changed during export");
                frame.ReadPixels(new Rect(0, 0, frame.width, frame.height), 0, 0, false);
                frame.Apply(false, false);
                byte[] png = frame.EncodeToPNG();
                encoder.StandardInput.BaseStream.Write(png, 0, png.Length);
            }
            catch (Exception error)
            {
                captureError = error;
            }
            if (captureError != null)
            {
                if (frame != null) Destroy(frame);
                Time.captureFramerate = 0;
                Fail(captureError);
                yield break;
            }
        }

        if (frame != null) Destroy(frame);
        Time.captureFramerate = 0;
        try
        {
            encoder.StandardInput.Close();
            if (!encoder.WaitForExit(60000))
                throw new IOException("FFmpeg timed out while finalizing MP4");
            if (encoder.ExitCode != 0)
                throw new IOException("FFmpeg exited with code " + encoder.ExitCode + ": " + EncoderError());
            if (!File.Exists(partialPath) || new FileInfo(partialPath).Length == 0)
                throw new IOException("FFmpeg did not produce an MP4");
            if (File.Exists(output)) throw new IOException("Output appeared during export: " + output);
            File.Move(partialPath, output);
            completed = true;
            Debug.Log("WALLWALL video exported: " + output);
            Application.Quit(0);
        }
        catch (Exception error)
        {
            Fail(error);
        }
    }

    private string EncoderError()
    {
        lock (encoderErrors) return encoderErrors.ToString();
    }

    private void Fail(Exception error)
    {
        Debug.LogError("WALLWALL video export failed: " + error);
        Application.Quit(1);
    }

    private void OnApplicationQuit()
    {
        if (encoder != null)
        {
            try
            {
                if (!encoder.HasExited)
                {
                    encoder.Kill();
                    encoder.WaitForExit(5000);
                }
            }
            catch (InvalidOperationException) { } // Process never started.
            encoder.Dispose();
        }
        if (!completed && partialPath != null && File.Exists(partialPath))
            File.Delete(partialPath);
    }
}
