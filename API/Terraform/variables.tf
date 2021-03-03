variable "restAPI-access-key" {
  type        = string 
}

variable "restAPI-secret-key" {
  type        = string 
}

variable "task-cpu" {
  default     = "256"
  type        = string
  description = "The number of cpu units used by the task."
}

variable "task-memory" {
  default     = "512"
  type        = string
  description = "The amount (in MiB) of memory used by the task."
}

variable "docker-cpu" {
  default     = 256
  type        = number
  description = "The number of cpu units used by the task."
}

variable "docker-memory" {
  default     = 512
  type        = number
  description = "The amount (in MiB) of memory used by the task."
}

variable "docker-image" {
  type        = string 
}

variable "desired-capacity" {
  type        = string 
}
