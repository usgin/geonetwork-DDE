/*
 * Copyright (C) 2001-2026 Food and Agriculture Organization of the
 * United Nations (FAO-UN), United Nations World Food Programme (WFP)
 * and United Nations Environment Programme (UNEP)
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or (at
 * your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA
 *
 * Contact: Jeroen Ticheler - FAO - Viale delle Terme di Caracalla 2,
 * Rome - Italy. email: geonetwork@osgeo.org
 */
package org.fao.geonet.schema;

import org.junit.Test;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Stream;

import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;

/**
 * Keeps the declared stylesheet versions honest.
 *
 * <p>A record's provenance reports the version of the stylesheet that produced it, so
 * a version left behind when the stylesheet changed is worse than none at all: the
 * output then carries a confident statement that is wrong. A hand-maintained value
 * cannot be trusted on discipline alone, so this compares each declared version with
 * the file's last commit date and fails when it has fallen behind.
 *
 * <p>Changing a versioned stylesheet therefore means bumping its {@code
 * stylesheetUpdated} in the same commit. The failure message says which file and what
 * to set.
 *
 * <p>Git is the only thing that knows when a file really last changed -- a working
 * copy's mtime says when it was checked out. Where git is unavailable or the history
 * is absent (a source export, a shallow clone), the check cannot run and is skipped
 * rather than failed.
 */
public class StylesheetUpdatedTest {

    private static final Path PLUGIN = Paths.get("src", "main", "plugin", "iso19115-3.2018");

    private static final Pattern DECLARED = Pattern.compile(
        "<xsl:variable\\s+name=\"stylesheetUpdated\"\\s+select=\"'([^']*)'\"\\s*/>");

    private static final Pattern ISO_DATE = Pattern.compile("\\d{4}-\\d{2}-\\d{2}");

    @Test
    public void everyDeclaredVersionMatchesTheFilesLastChange() throws Exception {
        List<Path> versioned = versionedStylesheets();
        assertTrue("no stylesheet declares a version -- has the convention been dropped?",
            !versioned.isEmpty());

        List<String> stale = new ArrayList<>();
        int checked = 0;
        for (Path sheet : versioned) {
            String declared = declaredVersion(sheet);
            assertTrue(sheet + " declares a version that is not a yyyy-mm-dd date: " + declared,
                ISO_DATE.matcher(declared).matches());

            String lastChange = lastCommitDate(sheet);
            if (lastChange.isEmpty()) {
                continue;   // no git history available here; see the class comment
            }
            checked++;
            if (declared.compareTo(lastChange) < 0) {
                stale.add(String.format("%s declares %s but last changed %s",
                    sheet, declared, lastChange));
            }
        }

        if (!stale.isEmpty()) {
            fail("Stylesheet versions have fallen behind. Set each stylesheetUpdated to the"
                + " date of the commit that changes it:\n  " + String.join("\n  ", stale));
        }
        System.out.println("StylesheetUpdatedTest: " + checked + " of " + versioned.size()
            + " versioned stylesheets checked against git");
    }

    private List<Path> versionedStylesheets() throws Exception {
        if (!Files.isDirectory(PLUGIN)) {
            return new ArrayList<>();
        }
        List<Path> found = new ArrayList<>();
        try (Stream<Path> walk = Files.walk(PLUGIN)) {
            for (Path candidate : (Iterable<Path>) walk.filter(Files::isRegularFile)
                .filter(p -> p.toString().endsWith(".xsl"))::iterator) {
                if (read(candidate).contains("stylesheetUpdated")) {
                    found.add(candidate);
                }
            }
        }
        return found;
    }

    private String declaredVersion(Path sheet) throws Exception {
        Matcher matcher = DECLARED.matcher(read(sheet));
        return matcher.find() ? matcher.group(1) : "";
    }

    private String read(Path path) throws Exception {
        return new String(Files.readAllBytes(path), StandardCharsets.UTF_8);
    }

    /**
     * Commit date of the file's most recent change, as yyyy-mm-dd, or an empty string
     * when git cannot answer.
     */
    private String lastCommitDate(Path sheet) {
        try {
            Path root = repositoryRoot();
            if (root == null) {
                return "";
            }
            // Relative to the repository root, with forward slashes: a git pathspec
            // wants them, and this module's own directory cannot be used as the
            // working directory -- see repositoryRoot.
            String relative = root.relativize(sheet.toAbsolutePath()).toString()
                .replace(java.io.File.separatorChar, '/');
            ProcessBuilder command = new ProcessBuilder(
                "git", "log", "-1", "--format=%cs", "--", relative);
            command.directory(root.toFile());
            command.redirectErrorStream(false);
            Process process = command.start();
            String answer;
            try (BufferedReader out = new BufferedReader(
                new InputStreamReader(process.getInputStream(), StandardCharsets.UTF_8))) {
                answer = out.readLine();
            }
            process.waitFor();
            if (process.exitValue() != 0 || answer == null) {
                return "";
            }
            answer = answer.trim();
            return ISO_DATE.matcher(answer).matches() ? answer : "";
        } catch (Exception e) {
            return "";
        }
    }

    /**
     * The working tree root: the nearest ancestor holding a {@code .git} DIRECTORY.
     *
     * <p>A directory, specifically. This module carries a stale {@code .git} FILE left
     * over from when it was a submodule, naming a gitdir that no longer exists, so git
     * run from anywhere inside it fails with "not a git repository" and every check
     * here silently passes on no data. Walking up to the real root sidesteps it.
     *
     * @return the root, or null when there is no git working tree above us
     */
    private Path repositoryRoot() {
        Path dir = Paths.get("").toAbsolutePath();
        while (dir != null) {
            if (Files.isDirectory(dir.resolve(".git"))) {
                return dir;
            }
            dir = dir.getParent();
        }
        return null;
    }
}
