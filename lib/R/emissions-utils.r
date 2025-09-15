#' Calculate emission categories from CRF data
#'
#' @export
fakta_calculate_emission_categories <- function(.data) {
  # Pivot to a wide tibble for easier calculations.
  pivot_wider(.data, names_from = "Code", values_from = "Value") |>
    # Group into sectors by summing components.
      PowerHeat = CRF1A1A,
      Industry = CRF1A2 + CRF1A1B + CRF1A1C + CRF1A3E + CRF2 + CRF1B,
      Transport = CRF1A3A + CRF1A3B + CRF1A3C + CRF1A3D + CRF1D1A,
      Buildings = CRF1A4A + CRF1A4B,
      Agriculture = CRF3 + CRF1A4C,
      Waste = CRF5,
      Other = TOTX4_MEMO + CRF1D1A - PowerHeat - Industry - Transport -
        Buildings - Agriculture - Waste
    ) |>
    select(!(starts_with("CRF") | starts_with("TOTX"))) |>
    # Turn back into long format.
    pivot_longer(
      PowerHeat:Other,
      names_to = "Category",
      values_to = "Value"
    )
}

#' Colour scheme for GHG emission sectors
#'
#' @export
emission_category_colours <-
  c(
    PowerHeat   = "#ff4245",
    Industry    = "#3b3b93",
    Transport   = "#8546af",
    Buildings   = "#0d80d8",
    Agriculture = "#1bb0a3",
    Waste       = "#fab519",
    Other       = "#b5b8bd"
  )
