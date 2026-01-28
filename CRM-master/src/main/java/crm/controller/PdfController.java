package crm.controller;

import com.itextpdf.text.Document;
import com.itextpdf.text.DocumentException;
import com.itextpdf.text.Paragraph;
import com.itextpdf.text.pdf.PdfWriter;
import crm.entity.Pdf;
import crm.service.PdfService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;

import javax.servlet.http.HttpServletResponse;
import javax.validation.Valid;
import java.io.IOException;

@Controller
@Slf4j
public class PdfController {

    private PdfService pdfService;

    public PdfController(PdfService pdfService) {
        this.pdfService = pdfService;
    }

    private void generateSamplePdf(String fileName, String text, HttpServletResponse response) throws IOException, DocumentException {
        if (!fileName.endsWith(".pdf")) {
            fileName += ".pdf";
        }
        response.setContentType("application/pdf");
        response.setHeader("Content-Disposition", "attachment; filename=\"" + fileName + "\"");
        Document document = new Document();
        PdfWriter.getInstance(document, response.getOutputStream());
        document.open();
        Paragraph paragraph = new Paragraph(text);
        document.add(paragraph);
        document.close();
    }

    @GetMapping("/pdf-generator")
    public String pdfGenerator(Model model) {
        model.addAttribute("pdf", new Pdf());
        return "pdf/generator";
    }

    @PostMapping("/pdf-generator")
    public String generatePdf(@Valid Pdf pdf, BindingResult bindingResult, HttpServletResponse response) {
        if (bindingResult.hasErrors()) {
            return "redirect:/pdf-generator";
        } else {
            try {
                generateSamplePdf(pdf.getName(), pdf.getContent(), response);
                pdfService.savePdf(pdf);
            } catch (IOException e) {
                log.info("IO Exception: " + e.getMessage());
            } catch (DocumentException e) {
                log.info("Document Exception: " + e.getMessage());
            }
            return "pdf/success";
        }
    }

}
