import de.featjar.base.cli.Commands;
import de.ovgu.featureide.fm.core.io.manager.FileHandler;
import de.ovgu.featureide.fm.core.io.xml.XmlFeatureModelFormat;

import java.nio.file.Path;
import java.time.Duration;

public class ModelToXMLFeatureIDE implements ITransformation {
    public void transform(Path inputPath, Path outputPath, Duration timeout) {
        Commands.runInThread(() -> {
            FileHandler.save(
                    outputPath,
                    ITransformation.loadModelFileWithFeatureIDE(inputPath),
                    new XmlFeatureModelFormat());
        }, timeout);
    }
}