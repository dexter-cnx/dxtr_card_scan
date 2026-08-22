use serde::Deserialize;

#[derive(Clone, Copy, Debug, Deserialize, PartialEq)]
pub struct NormalizedRect {
    pub left: f32,
    pub top: f32,
    pub right: f32,
    pub bottom: f32,
}

impl NormalizedRect {
    pub fn validate(self) -> Result<Self, String> {
        let values = [self.left, self.top, self.right, self.bottom];
        if values.iter().any(|value| !value.is_finite()) {
            return Err("ROI coordinates must be finite".to_owned());
        }
        if self.left < 0.0
            || self.top < 0.0
            || self.right > 1.0
            || self.bottom > 1.0
            || self.left >= self.right
            || self.top >= self.bottom
        {
            return Err("ROI must be a non-empty normalized rectangle inside [0,1]".to_owned());
        }
        Ok(self)
    }

    pub fn rotated_clockwise(self, quarter_turns: u8) -> Self {
        match quarter_turns % 4 {
            0 => self,
            1 => Self {
                left: 1.0 - self.bottom,
                top: self.left,
                right: 1.0 - self.top,
                bottom: self.right,
            },
            2 => Self {
                left: 1.0 - self.right,
                top: 1.0 - self.bottom,
                right: 1.0 - self.left,
                bottom: 1.0 - self.top,
            },
            3 => Self {
                left: self.top,
                top: 1.0 - self.right,
                right: self.bottom,
                bottom: 1.0 - self.left,
            },
            _ => unreachable!(),
        }
    }
}

#[derive(Clone, Copy, Debug, Default, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum OutputFormat {
    #[default]
    Jpeg,
    Png,
}

#[derive(Clone, Debug, Deserialize, PartialEq)]
#[serde(default)]
pub struct ProcessorOptions {
    pub quarter_turns_clockwise: u8,
    pub roi: Option<NormalizedRect>,
    pub grayscale: bool,
    pub max_dimension: Option<u32>,
    pub output_format: OutputFormat,
    pub jpeg_quality: u8,
}

impl Default for ProcessorOptions {
    fn default() -> Self {
        Self {
            quarter_turns_clockwise: 0,
            roi: None,
            grayscale: false,
            max_dimension: None,
            output_format: OutputFormat::Jpeg,
            jpeg_quality: 92,
        }
    }
}

impl ProcessorOptions {
    pub fn validate(mut self) -> Result<Self, String> {
        self.quarter_turns_clockwise %= 4;
        if let Some(roi) = self.roi {
            self.roi = Some(roi.validate()?);
        }
        if self.max_dimension == Some(0) {
            return Err("max_dimension must be greater than zero when provided".to_owned());
        }
        if !(1..=100).contains(&self.jpeg_quality) {
            return Err("jpeg_quality must be in 1..=100".to_owned());
        }
        Ok(self)
    }
}
