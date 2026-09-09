import Foundation

enum DocumentConverter {
    typealias Table = [[String]]

    static func convert(input: URL, output: URL, to format: MediaFormat) throws {
        let rows = try readTable(from: input)
        guard !rows.isEmpty else {
            throw MediaConversionError.cannotReadInput
        }
        try writeTable(rows, to: output, format: format)
    }

    // MARK: - Read

    private static func readTable(from url: URL) throws -> Table {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "csv":
            let text = try readText(from: url)
            return parseDelimited(text, delimiter: ",")
        case "tsv", "txt":
            let text = try readText(from: url)
            return parseDelimited(text, delimiter: "\t")
        case "xlsx":
            return try readXLSX(from: url)
        default:
            throw MediaConversionError.unsupportedFormat
        }
    }

    private static func readText(from url: URL) throws -> String {
        if let utf8 = try? String(contentsOf: url, encoding: .utf8) {
            return utf8
        }
        if let latin1 = try? String(contentsOf: url, encoding: .isoLatin1) {
            return latin1
        }
        throw MediaConversionError.cannotReadInput
    }

    static func parseDelimited(_ text: String, delimiter: Character) -> Table {
        var rows: Table = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var index = text.startIndex

        func finishField() {
            row.append(field)
            field = ""
        }

        func finishRow() {
            finishField()
            if !row.isEmpty || !rows.isEmpty {
                rows.append(row)
            }
            row = []
        }

        while index < text.endIndex {
            let char = text[index]

            if inQuotes {
                if char == "\"" {
                    let next = text.index(after: index)
                    if next < text.endIndex, text[next] == "\"" {
                        field.append("\"")
                        index = next
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(char)
                }
            } else if char == "\"" {
                inQuotes = true
            } else if char == delimiter {
                finishField()
            } else if char == "\r" {
                let next = text.index(after: index)
                if next < text.endIndex, text[next] == "\n" {
                    index = next
                }
                finishRow()
            } else if char == "\n" {
                finishRow()
            } else {
                field.append(char)
            }

            index = text.index(after: index)
        }

        if inQuotes {
            finishRow()
        } else if !field.isEmpty || !row.isEmpty {
            finishRow()
        }

        return rows
    }

    private static func readXLSX(from url: URL) throws -> Table {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("convertit-xlsx-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        try unzip(archive: url, to: temp)

        let sharedStringsURL = temp.appendingPathComponent("xl/sharedStrings.xml")
        let sharedStrings: [String]
        if FileManager.default.fileExists(atPath: sharedStringsURL.path) {
            let xml = try Data(contentsOf: sharedStringsURL)
            sharedStrings = SharedStringsXMLParser.parse(xml)
        } else {
            sharedStrings = []
        }

        let sheetURL = try resolveFirstWorksheetURL(in: temp)
        let sheetXML = try Data(contentsOf: sheetURL)
        let rows = WorksheetXMLParser.parse(sheetXML, sharedStrings: sharedStrings)
        guard !rows.isEmpty else {
            throw MediaConversionError.cannotReadInput
        }
        return rows
    }

    private static func resolveFirstWorksheetURL(in extractedRoot: URL) throws -> URL {
        let workbookRels = extractedRoot.appendingPathComponent("xl/_rels/workbook.xml.rels")
        if FileManager.default.fileExists(atPath: workbookRels.path),
           let relsData = try? Data(contentsOf: workbookRels),
           let target = RelationshipsXMLParser.firstWorksheetTarget(relsData) {
            let sheetURL = extractedRoot.appendingPathComponent("xl/\(target)")
            if FileManager.default.fileExists(atPath: sheetURL.path) {
                return sheetURL
            }
        }

        let defaultSheet = extractedRoot.appendingPathComponent("xl/worksheets/sheet1.xml")
        guard FileManager.default.fileExists(atPath: defaultSheet.path) else {
            throw MediaConversionError.exportFailed("Could not find a worksheet inside the Excel file.")
        }
        return defaultSheet
    }

    private static func decodeXMLEntities(_ text: String) -> String {
        SpreadsheetXML.decodeEntities(text)
    }

    private static func encodeXMLEntities(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    static func columnIndex(from cellRef: String) -> Int {
        let letters = cellRef.prefix { $0.isLetter }
        var index = 0
        for char in letters {
            index = index * 26 + Int(char.uppercased().unicodeScalars.first!.value - 64)
        }
        return max(index - 1, 0)
    }

    static func filledRow(_ sparse: [Int: String], through maxColumn: Int) -> [String] {
        guard maxColumn >= 0 else { return [] }
        return (0...maxColumn).map { sparse[$0] ?? "" }
    }

    // MARK: - Write

    private static func writeTable(_ rows: Table, to output: URL, format: MediaFormat) throws {
        switch format.id {
        case "csv":
            let text = serializeDelimited(rows, delimiter: ",")
            try text.write(to: output, atomically: true, encoding: .utf8)
        case "tsv":
            let text = serializeDelimited(rows, delimiter: "\t")
            try text.write(to: output, atomically: true, encoding: .utf8)
        case "xlsx":
            try writeXLSX(rows, to: output)
        default:
            throw MediaConversionError.unsupportedFormat
        }
    }

    private static func serializeDelimited(_ rows: Table, delimiter: String) -> String {
        rows.map { row in
            row.map { field in
                if field.contains(delimiter) || field.contains("\"") || field.contains("\n") || field.contains("\r") {
                    "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
                } else {
                    field
                }
            }.joined(separator: delimiter)
        }.joined(separator: "\n")
    }

    private static func writeXLSX(_ rows: Table, to output: URL) throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("convertit-xlsx-out-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: temp.appendingPathComponent("_rels"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: temp.appendingPathComponent("xl/_rels"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: temp.appendingPathComponent("xl/worksheets"), withIntermediateDirectories: true)

        let contentTypes = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
          <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
        </Types>
        """
        let rootRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
        </Relationships>
        """
        let workbook = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <sheets>
            <sheet name="Sheet1" sheetId="1" r:id="rId1"/>
          </sheets>
        </workbook>
        """
        let workbookRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
        </Relationships>
        """

        var sheetRows: [String] = []
        for (rowIndex, row) in rows.enumerated() {
            var cells: [String] = []
            for (columnIndex, value) in row.enumerated() {
                let ref = cellReference(row: rowIndex + 1, column: columnIndex)
                let escaped = encodeXMLEntities(value)
                cells.append("<c r=\"\(ref)\" t=\"inlineStr\"><is><t>\(escaped)</t></is></c>")
            }
            sheetRows.append("<row r=\"\(rowIndex + 1)\">\(cells.joined())</row>")
        }

        let worksheet = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <sheetData>
            \(sheetRows.joined())
          </sheetData>
        </worksheet>
        """

        try contentTypes.write(to: temp.appendingPathComponent("[Content_Types].xml"), atomically: true, encoding: .utf8)
        try rootRels.write(to: temp.appendingPathComponent("_rels/.rels"), atomically: true, encoding: .utf8)
        try workbook.write(to: temp.appendingPathComponent("xl/workbook.xml"), atomically: true, encoding: .utf8)
        try workbookRels.write(to: temp.appendingPathComponent("xl/_rels/workbook.xml.rels"), atomically: true, encoding: .utf8)
        try worksheet.write(to: temp.appendingPathComponent("xl/worksheets/sheet1.xml"), atomically: true, encoding: .utf8)

        if FileManager.default.fileExists(atPath: output.path) {
            try FileManager.default.removeItem(at: output)
        }
        try zip(directory: temp, to: output)
    }

    private static func cellReference(row: Int, column: Int) -> String {
        var index = column
        var letters = ""
        repeat {
            let remainder = index % 26
            let scalar = UnicodeScalar(65 + remainder)!
            letters = String(Character(scalar)) + letters
            index = index / 26 - 1
        } while index >= 0
        return "\(letters)\(row)"
    }

    // MARK: - Archive helpers

    private static func unzip(archive: URL, to directory: URL) throws {
        let ditto = Process()
        ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        ditto.arguments = ["-xk", archive.path, directory.path]
        let dittoErr = Pipe()
        ditto.standardError = dittoErr
        try ditto.run()
        ditto.waitUntilExit()
        if ditto.terminationStatus == 0 { return }

        let unzip = Process()
        unzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        unzip.arguments = ["-o", "-qq", archive.path, "-d", directory.path]
        let unzipErr = Pipe()
        unzip.standardError = unzipErr
        try unzip.run()
        unzip.waitUntilExit()
        guard unzip.terminationStatus == 0 else {
            let err = String(data: unzipErr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "Unknown error"
            throw MediaConversionError.exportFailed(
                err.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "Could not open the Excel file."
                    : err.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }

    private static func zip(directory: URL, to archive: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-rq", archive.path, "."]
        process.currentDirectoryURL = directory
        let pipe = Pipe()
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let err = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "Unknown error"
            throw MediaConversionError.exportFailed(err.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}

// MARK: - XML parsing

private enum SpreadsheetXML {
    static func localName(_ name: String) -> String {
        name.split(separator: ":").last.map(String.init) ?? name
    }

    static func decodeEntities(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
    }
}

private final class SharedStringsXMLParser: NSObject, XMLParserDelegate {
    static func parse(_ data: Data) -> [String] {
        let parser = SharedStringsXMLParser()
        let xml = XMLParser(data: data)
        xml.delegate = parser
        xml.parse()
        return parser.strings
    }

    private var strings: [String] = []
    private var currentSI = ""
    private var currentText = ""
    private var depthInSI = 0
    private var depthInT = 0

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes attributeDict: [String: String] = [:]) {
        let name = SpreadsheetXML.localName(elementName)
        if name == "si" {
            depthInSI += 1
            if depthInSI == 1 {
                currentSI = ""
            }
        } else if name == "t", depthInSI > 0 {
            depthInT += 1
            if depthInT == 1 {
                currentText = ""
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if depthInT > 0 {
            currentText += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        let name = SpreadsheetXML.localName(elementName)
        if name == "t", depthInT > 0 {
            depthInT -= 1
            if depthInT == 0 {
                currentSI += SpreadsheetXML.decodeEntities(currentText)
                currentText = ""
            }
        } else if name == "si", depthInSI > 0 {
            depthInSI -= 1
            if depthInSI == 0 {
                strings.append(currentSI)
                currentSI = ""
            }
        }
    }
}

private final class RelationshipsXMLParser: NSObject, XMLParserDelegate {
    static func firstWorksheetTarget(_ data: Data) -> String? {
        let parser = RelationshipsXMLParser()
        let xml = XMLParser(data: data)
        xml.delegate = parser
        xml.parse()
        return parser.worksheetTarget
    }

    private var worksheetTarget: String?

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes attributeDict: [String: String] = [:]) {
        guard SpreadsheetXML.localName(elementName) == "Relationship" else { return }
        guard let type = attributeDict["Type"],
              type.contains("worksheet"),
              let target = attributeDict["Target"] else { return }
        if worksheetTarget == nil {
            worksheetTarget = target
        }
    }
}

private final class WorksheetXMLParser: NSObject, XMLParserDelegate {
    static func parse(_ data: Data, sharedStrings: [String]) -> [[String]] {
        let parser = WorksheetXMLParser(sharedStrings: sharedStrings)
        let xml = XMLParser(data: data)
        xml.delegate = parser
        xml.parse()
        return parser.rows
    }

    private let sharedStrings: [String]
    private var rows: [[String]] = []
    private var sparseRow: [Int: String] = [:]
    private var currentCellRef = ""
    private var currentCellType = ""
    private var currentValue = ""
    private var depthInV = 0
    private var depthInT = 0
    private var depthInCell = 0

    init(sharedStrings: [String]) {
        self.sharedStrings = sharedStrings
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes attributeDict: [String: String] = [:]) {
        let name = SpreadsheetXML.localName(elementName)
        switch name {
        case "row":
            flushRowIfNeeded(finalize: true)
            sparseRow = [:]
        case "c":
            depthInCell += 1
            if depthInCell == 1 {
                currentCellRef = attributeDict["r"] ?? ""
                currentCellType = attributeDict["t"] ?? ""
                currentValue = ""
            }
        case "v":
            depthInV += 1
            if depthInV == 1 { currentValue = "" }
        case "t":
            depthInT += 1
            if depthInT == 1 { currentValue = "" }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if depthInV > 0 || depthInT > 0 {
            currentValue += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        let name = SpreadsheetXML.localName(elementName)
        switch name {
        case "v":
            if depthInV > 0 { depthInV -= 1 }
        case "t":
            if depthInT > 0 { depthInT -= 1 }
        case "c":
            if depthInCell > 0 {
                depthInCell -= 1
                if depthInCell == 0 {
                    let column = DocumentConverter.columnIndex(from: currentCellRef)
                    sparseRow[column] = resolvedCellValue()
                }
            }
        case "row":
            flushRowIfNeeded(finalize: true)
        default:
            break
        }
    }

    private func resolvedCellValue() -> String {
        let trimmed = currentValue.trimmingCharacters(in: .whitespacesAndNewlines)
        switch currentCellType {
        case "s":
            guard let index = Int(trimmed), sharedStrings.indices.contains(index) else { return trimmed }
            return sharedStrings[index]
        case "inlineStr":
            return SpreadsheetXML.decodeEntities(trimmed)
        case "b":
            return trimmed == "1" ? "TRUE" : "FALSE"
        default:
            return SpreadsheetXML.decodeEntities(trimmed)
        }
    }

    private func flushRowIfNeeded(finalize: Bool) {
        guard finalize, !sparseRow.isEmpty else { return }
        rows.append(DocumentConverter.filledRow(sparseRow, through: sparseRow.keys.max() ?? 0))
        sparseRow = [:]
    }
}
