source('C:/rprojects/hasznaltauto/R/functions.R')
library(parallel)

n_pages <- SleepyRead("https://www.hasznaltauto.hu/talalatilista/PCOG2U6RV3NDADH5S56ACFFYNTQXCE52JAJZUNDJV6K2DJUEEYYUVUXKALRN7ZZUUW2IZJ2YY53HY7DSAJZLNFBXF6TZSFAVAQWMSKOYMIRVNDCNUXYFONFIF5IAO2VBXEKKBR4F3MHD6KSXMBAN6QAB7YVFMOZZ5EXGSGGW4BZKG3CXHYCODKYDC5JGB3PS76VV6E35I6OMVMZM5CIJ7QEZXLSSRRNUHWLVFFHAYDXBK2HF34KGI4J72BSN7ZDY4YHB32RDAZ5JH3XXUU2ZYAU4UBRTJEPCYASFTAKNIHHWKO3MVRAA6PXWMHBA47NNQOHTHGC5GZUYO7L3CX3YO54HU43CZQJHDH6IHLSRPP2CTEPRQB662A4ZL7FIPX4OBQCUK5STUT2EPW7WO6Z63NSKQO7EXIP43KSR4ZOLWXJACXPKMAJAMXAFXHVK5YDCIMCWVXJDLQJNJOPWE7KPCOWW4JQSG3CYIIEOH7L3OCYH7JI2CVRPXNT3UABTWL4EZIGFUR7IUOL5TVHMKWYBOKH33NAGWOCTCAVZAC3ZKPEZB3ITFI4U24IW4MWMLMYYZ5JDZD7RHTCQXMN2OMYGHTOQS3UGUN64MQGPPXXEHZ3AMVJZLPGMBE32VXI6GCDF5KWJQRTTUUVFFZNKLMVWN7DVAYBAZX4IRPE7W26F32WIN6CHPQ5DVKFP2GBTFCQ2VMIJ7X7HWDJTA2UKGN2M2PVU5ICQ42GOOH3ORNXWX5CJOXJLWKLWNGDDCHIJ6X4IGZSOSSEOZIQ34TC7T776KEDFDNLVVGORVLYQH4ZUWQL7J6MBLQE5UDDY32J4Q3HDT62K6DO2AHM7WP6VKGDZ6") %>% 
  html_nodes(".last a") %>% 
  html_text() %>% 
  first() %>% 
  as.numeric()


url_to_lists <-  str_c(
  "https://www.hasznaltauto.hu/talalatilista/PCOG2VGRV3NDADH5S56ACFFYS6C4OTLIJAJZUNDJV6KQCU2CSMMCK2LVFHRN7ZZUUW2IYJ5MMO5T4PR6AHSGYKLPLZHDGKKKBBMJAU5QYVNKYGE3JLQRWNFIV5IAK2VBXEKKBR4FLPDJOUXMVBLACQ2IIDWK2MNAA2LRWZO7QDYNLAILFGYHF6P72WXYTPUDJGOMANYWOTEM7YCM2VJJGYW27Z7EUUMAAO5VPIEVP5JZBRNVICJX3E7DTE5XJKCPDDUE2OSOK3XMBDD4BUD6MICWHM4RSZLIBXTQAZ7IXBHKIOBSPWXN2HHIFFBYPDNV5HA4PJV4RJBV72PA4N2ONHKNLINMWVY2366TWPSVMNYX5EWBH7UGVNKHT4JBSD6YK47JB6NFPT4O3SCQKBSDPB4U7ZUNX7TOW3O342OQG4UZIX532SRWZMKWHKQOW33OYCKZBK7OCNOGZ2EALL3QRFYEOWU7YGLV7QOGX4PQCXLCYLUE6H7D2OGYX5KNCVV2FNRATDTMYUIEUM3IDWQY6XTGKOYXTQK6UHUL6BS2YOC5RIZAC7ZKNUXJ3LRSUOKNOELOGLGFWMMM6UR4R7YTZRILWG5HGMDDZXIBN2BKG7OGIDHXV3ST45QGSU4ZXT6ASN5KLUPDBBS6VLEYI3JVAGNJOLK22FJTHZBQGAMGG7RGF4V6FHM3LZIQ76EKPI5D7INB3FCR2RMIM6D6T7BU5Q5IFHHNAFP32CVBOOFAXHCNTI5PWUXSTOVMFHEV523BRZCUA73ZEFNJHJITHEVIN6DH7JJ6AFZ3ITM4NJKWM22GU7G2HQG62FL5PYSFPABWAOPPOJBS3P4AP3JLQN3EB5X6B7ZQXDJY/page", 1:n_pages
)

cl <- makeCluster(7)
clusterEvalQ(cl, library(rvest))
clusterEvalQ(cl, library(tidyverse))
clusterExport(cl, list("SafelyRead", "url_to_lists", "GetURL", "GetHTMLText"), envir = environment())

available_cars <- parLapply(cl, url_to_lists, function(url) {
  SafelyRead(url) %>% 
    {tibble(url_to_car = GetURL(., ".cim-kontener a"), price = GetHTMLText(., ".vetelar"))}
})

stopCluster(cl)

available_cars <- available_cars %>% 
  reduce(rbind) %>% 
  na.omit()

write_rds(available_cars, file = str_c("C:/rprojects/hasznaltauto/data/available_cars/available_cars_", Sys.Date(), ".RDS"))

message("Scrape cars")

for (i in 1:100) {
  
  cars_data <- available_cars %>% 
    filter(cut(row_number(), 100, FALSE) == i) %>% 
    mutate(page = map(url_to_car, SleepyRead)) %>% 
    filter(map_lgl(page, ~ !is.na(.))) %>% 
    mutate(
      data = map(page, html_table, fill = TRUE),
      other_data = map(page, GetHTMLText, "#adatlap li"),
      description = map(page, GetHTMLText, ".leiras div"),
      contact = map(page, GetHTMLText, ".contact-button-text"),
    ) %>% 
    select(url_to_car, data, other_data, description, contact)
  
  available_cars_repeat <- available_cars %>% 
    filter(cut(row_number(), 100, FALSE) == i) %>% 
    anti_join(select(cars_data, url_to_car)) 
  
  if (nrow(available_cars_repeat) != 0) {
    
    available_cars_repeat <- available_cars_repeat %>% 
      mutate(page = map(url_to_car, SleepyRead)) %>% 
      filter(map_lgl(page, ~ !is.na(.))) %>% 
      mutate(
        data = map(page, html_table, fill = TRUE),
        other_data = map(page, GetHTMLText, "#adatlap li"),
        description = map(page, GetHTMLText, ".leiras div"),
        contact = map(page, GetHTMLText, ".contact-button-text"),
      ) %>% 
      select(url_to_car, data, other_data, description, contact)
    
    cars_data <- rbind(cars_data, available_cars_repeat)
  }
  
  write_rds(cars_data, file = str_c("C:/rprojects/hasznaltauto/data/cars_data/cars_data_", i, "_", Sys.Date(), ".RDS"))
  print(str_c(i, " %"))
}

tcltk::tkmessageBox(title = "Title of message box",
                    message = str_c("Scrape finished at ", Sys.time()), icon = "info", type = "ok")
